import UIKit
import ReownWalletKit
import WalletConnectSign
import Commons

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let app = Application()
    private lazy var coordinator = NavigationCoordinator(app: app)

    private var configurators: [Configurator] {
        return [
            MigrationConfigurator(app: app),
            ThirdPartyConfigurator(),
            ApplicationConfigurator(app: app, coordinator: coordinator),
            AppearanceConfigurator()
        ]
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }

        // Check if the Universal Link is a payment URL (e.g. pay.walletconnect.com).
        // This handles both NFC Background Tag Reading and regular Universal Link taps.
        let urlString = url.absoluteString
        if WalletKit.isPaymentLink(urlString) {
            NFCPaymentReader.suppressAutoScan = true
            handlePaymentLink(urlString)
            return
        }

        // Extract topic from URL
        if let topic = extractTopicFromURL(url.absoluteString) {
            LinkModeTopicsStorage.shared.addTopic(topic)
        }

        do {
            try WalletKit.instance.dispatchEnvelope(url.absoluteString)
        } catch {
            print(error)
        }
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Setup the window
        window = UIWindow(windowScene: windowScene)
        window?.makeKeyAndVisible()

        configureWalletKitClientIfNeeded()
        app.requestSent = (connectionOptions.urlContexts.first?.url.absoluteString.replacingOccurrences(of: "walletapp://wc?", with: "") == "requestSent")

        // Check for widget "Tap to Pay" deep link on cold start
        if let urlContext = connectionOptions.urlContexts.first,
           urlContext.url.scheme == "walletapp" && urlContext.url.host == "nfc-pay" {
            configurators.configure()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.triggerNfcScan()
            }
            return
        }

        // Check for payment deep link on cold start
        var pendingPaymentLink: String?
        if let url = connectionOptions.urlContexts.first?.url {
            pendingPaymentLink = extractPaymentLink(from: url)
        }

        // Check for payment Universal Link on cold start (e.g. NFC Background Tag Reading).
        // Universal Links arrive via userActivities, not urlContexts.
        if pendingPaymentLink == nil,
           let url = connectionOptions.userActivities
               .first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?.webpageURL,
           WalletKit.isPaymentLink(url.absoluteString) {
            pendingPaymentLink = url.absoluteString
        }

        // Process connection options (only if not a pay-only deeplink)
        // If `pay` param exists but no `uri`, skip pairing
        let hasPayParam = pendingPaymentLink != nil
        let hasUriParam = connectionOptions.urlContexts.first.flatMap { context -> Bool in
            guard let components = URLComponents(url: context.url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else { return false }
            return queryItems.contains(where: { $0.name == "uri" })
        } ?? false

        if !hasPayParam || hasUriParam {
            do {
                // Attempt to initialize WalletConnectURI from connection options
                let uri = try WalletConnectURI(connectionOptions: connectionOptions)
                app.uri = uri
            } catch {
                // Try to handle link mode in case where WalletConnectURI initialization fails
                if let url = connectionOptions.userActivities.first?.webpageURL {
                    configurators.configure() // Ensure configurators are set up before dispatching

                    // Extract topic from URL
                    if let topic = extractTopicFromURL(url.absoluteString) {
                        LinkModeTopicsStorage.shared.addTopic(topic)
                    }

                    do {
                        try WalletKit.instance.dispatchEnvelope(url.absoluteString)
                    } catch {
                        print("Error dispatching envelope: \(error.localizedDescription)")
                    }
                    return
                }
            }
        }
        configurators.configure()

        // Handle pending payment after configuration is complete
        if let paymentLink = pendingPaymentLink {
            // Suppress NFC auto-scan — payment modal will be shown instead.
            NFCPaymentReader.suppressAutoScan = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handlePaymentLink(paymentLink)
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Control Center widget writes a flag to shared UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.walletconnect.sdk")
        if defaults?.bool(forKey: "pendingNfcPay") == true {
            defaults?.removeObject(forKey: "pendingNfcPay")
            triggerNfcScan()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else { return }

        let url = context.url

        // Handle widget "Tap to Pay" deep link
        if url.scheme == "walletapp" && url.host == "nfc-pay" {
            triggerNfcScan()
            return
        }

        // Check for payment deep link and handle if found
        if let paymentLink = extractPaymentLink(from: url) {
            handlePaymentLink(paymentLink)
            // For POS scan format (walletconnectpay host), return early - no pairing needed
            if url.host == "walletconnectpay" {
                return
            }
            // For new format (uri with pay param), continue to pairing flow
        }

        do {
            let uri = try WalletConnectURI(urlContext: context)
            Task {
                try await WalletKit.instance.pair(uri: uri)
            }
        } catch {
            if case WalletConnectURI.Errors.expired = error {
                WalletToast.present(message: error.localizedDescription, type: .error)
            } else {
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let queryItems = components.queryItems,
                      queryItems.contains(where: { $0.name == "wc_ev" }) else {
                    return
                }

                // Extract topic from URL
                if let topic = extractTopicFromURL(url.absoluteString) {
                    LinkModeTopicsStorage.shared.addTopic(topic)
                }

                do {
                    try WalletKit.instance.dispatchEnvelope(url.absoluteString)
                } catch {
                    WalletToast.present(message: error.localizedDescription, type: .error)
                }
            }
        }
    }


}

private extension SceneDelegate {

    func triggerNfcScan() {
        NFCPaymentReader.suppressAutoScan = true
        NFCPaymentReader.shared.scan { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let urlString):
                    self?.handleScannedPaymentUrl(urlString)
                case .failure(let error):
                    if case NFCPaymentError.cancelled = error { return }
                    WalletToast.present(message: error.localizedDescription, type: .error)
                }
            }
        }
    }

    func handleScannedPaymentUrl(_ urlString: String) {
        if WalletKit.isPaymentLink(urlString) {
            handlePaymentLink(urlString)
            return
        }
        print("NFC scan returned non-payment URL: \(urlString)")
    }


    func configureWalletKitClientIfNeeded() {
        Networking.configure(
            groupIdentifier: "group.com.walletconnect.sdk",
            projectId: InputConfig.projectId,
            socketFactory: DefaultSocketFactory()
        )
        

        guard let redirect = try? AppMetadata.Redirect(native: "walletapp://", universal: "https://lab.reown.com/wallet", linkMode: true) else {
            print("[WalletKit] Failed to create redirect metadata")
            return
        }
        let metadata = AppMetadata(
            name: "Swift Wallet",
            description: "Swift sample wallet showcasing WalletConnect SDK integration",
            url: "https://walletconnect.network/sdk",
            icons: ["https://avatars.githubusercontent.com/u/37784886"],
            redirect: redirect
        )

        #if DEBUG
        WalletKit.configure(metadata: metadata, crypto: DefaultCryptoProvider(), pimlicoApiKey: InputConfig.pimlicoApiKey, payLogging: true)
        #else
        WalletKit.configure(metadata: metadata, crypto: DefaultCryptoProvider(), pimlicoApiKey: InputConfig.pimlicoApiKey)
        #endif
    }

    // Helper method to extract topic from URL
    private func extractTopicFromURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              // Check that wc_ev is present in query parameters
              queryItems.contains(where: { $0.name == "wc_ev" }) else {
            return nil
        }

        return queryItems.first(where: { $0.name == "topic" })?.value
    }

    /// Extract payment link from a URL if present.
    /// Supports WC URI format (`uri` param with embedded `pay`) and
    /// POS scan format (`walletconnectpay` host with `paymentId`).
    private func extractPaymentLink(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }

        // WC URI with embedded pay param — Yttrium handles extraction
        if let uriValue = queryItems.first(where: { $0.name == "uri" })?.value,
           WalletKit.isPaymentLink(uriValue) {
            return uriValue
        }

        // POS scan format: walletconnectpay host with paymentId
        if url.host == "walletconnectpay",
           let paymentId = queryItems.first(where: { $0.name == "paymentId" })?.value {
            return "walletapp://walletconnectpay?paymentId=\(paymentId)"
        }

        return nil
    }
    
    /// Handle a payment link URL via the coordinator
    private func handlePaymentLink(_ paymentLink: String) {
        coordinator.showPayment(paymentLink: paymentLink)
    }
}

