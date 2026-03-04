import SafariServices
import UIKit
import ReownWalletKit
import WalletConnectSign
import Commons

final class SceneDelegate: UIResponder, UIWindowSceneDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    private let app = Application()

    private var configurators: [Configurator] {
        return [
            MigrationConfigurator(app: app),
            ThirdPartyConfigurator(),
            ApplicationConfigurator(app: app),
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

        // Notification center delegate setup
        UNUserNotificationCenter.current().delegate = self

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
                AlertPresenter.present(message: error.localizedDescription, type: .error)
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
                    AlertPresenter.present(message: error.localizedDescription, type: .error)
                }
            }
        }
    }


    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        open(notification: notification)
        return [.sound, .banner, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        open(notification: response.notification)
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
                    AlertPresenter.present(message: error.localizedDescription, type: .error)
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

    func open(notification: UNNotification) {
        let popupTag: Int = 1020
        if let url = URL(string: notification.request.content.subtitle),
           let topController = window?.rootViewController?.topController, topController.view.tag != popupTag
        {
            let safari = SFSafariViewController(url: url)
            safari.modalPresentationStyle = .formSheet
            safari.view.tag = popupTag
            window?.rootViewController?.topController.present(safari, animated: true)
        }
    }

    func configureWalletKitClientIfNeeded() {
        Networking.configure(
            groupIdentifier: "group.com.walletconnect.sdk",
            projectId: InputConfig.projectId,
            socketFactory: DefaultSocketFactory()
        )
        

        let metadata = AppMetadata(
            name: "Example Wallet",
            description: "wallet description",
            url: "example.wallet",
            icons: ["https://avatars.githubusercontent.com/u/37784886"],
            redirect: try! AppMetadata.Redirect(native: "walletapp://", universal: "https://lab.web3modal.com/wallet", linkMode: true)
        )

        #if DEBUG
        WalletKit.configure(metadata: metadata, crypto: DefaultCryptoProvider(), environment: BuildConfiguration.shared.apnsEnvironment, pimlicoApiKey: InputConfig.pimlicoApiKey, payLogging: true)
        #else
        WalletKit.configure(metadata: metadata, crypto: DefaultCryptoProvider(), environment: BuildConfiguration.shared.apnsEnvironment, pimlicoApiKey: InputConfig.pimlicoApiKey)
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
    
    /// Present the payment flow for the given payment link.
    private func handlePaymentLink(_ paymentLink: String) {
        guard let topController = window?.rootViewController?.topController else { return }

        guard let account = AccountStorage(defaults: .standard).importAccount else {
            AlertPresenter.present(message: "No account found. Please import an account first.", type: .error)
            return
        }

        let address = account.account.address
        let accounts = [
            "eip155:1:\(address)",
            "eip155:137:\(address)",
            "eip155:8453:\(address)"
        ]

        let paymentVC = PayModule.create(
            app: app,
            paymentLink: paymentLink,
            accounts: accounts,
            importAccount: account
        )
        paymentVC.modalPresentationStyle = .overCurrentContext
        paymentVC.view.backgroundColor = .clear
        topController.present(paymentVC, animated: true)
    }
}

