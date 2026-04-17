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
        guard let url = userActivity.webpageURL else {
            return
        }

        if handleIncomingURL(url) {
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

        // Check for payment deep link on cold start
        var pendingPaymentLink: String?
        if let url = connectionOptions.urlContexts.first?.url {
            pendingPaymentLink = extractPaymentLink(from: url)
        } else if let userActivityURL = connectionOptions.userActivities.first?.webpageURL {
            pendingPaymentLink = extractPaymentLink(from: userActivityURL)
        }

        // Process connection options (only if not a pay-only deeplink)
        // If `pay` param exists but no `uri`, skip pairing
        let hasPayParam = pendingPaymentLink != nil
        let incomingURL = connectionOptions.urlContexts.first?.url ?? connectionOptions.userActivities.first?.webpageURL
        let hasUriParam = incomingURL.flatMap { url -> Bool in
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
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

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else { return }

        let url = context.url

        if handleIncomingURL(url) {
            return
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
    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        guard let paymentLink = extractPaymentLink(from: url) else {
            return false
        }

        // Suppress NFC auto-scan — payment modal will be shown instead.
        NFCPaymentReader.suppressAutoScan = true
        handlePaymentLink(paymentLink)

        if containsWalletConnectURI(in: url) {
            return false
        }

        // Mirror the Paste URL flow for direct payment links: start Pay only.
        return true
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
    /// Supports:
    /// - WC URI format: `uri` parameter containing embedded `pay` param
    /// - Gateway / universal links with `pid` or `paymentId` query params
    /// - App deeplinks with `walletconnectpay?paymentId=...`
    private func extractPaymentLink(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }

        // WC URI with embedded pay param — Yttrium handles extraction
        if let uriValue = queryItems.first(where: { $0.name == "uri" })?.value,
           WalletKit.isPaymentLink(uriValue) {
            return uriValue
        }

        // App deeplink format: extract the bare payment ID instead of forwarding the
        // custom walletapp:// URL, which Pay rejects.
        if url.host == "walletconnectpay",
           let paymentId = queryItems.first(where: { $0.name == "paymentId" })?.value,
           !paymentId.isEmpty {
            return paymentId
        }

        // For gateway / universal links, preserve the original URL exactly.
        if let paymentId = queryItems.first(where: { $0.name == "paymentId" || $0.name == "pid" })?.value,
           !paymentId.isEmpty {
            return url.absoluteString
        }

        return nil
    }

    private func containsWalletConnectURI(in url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let uriValue = components.queryItems?.first(where: { $0.name == "uri" })?.value else {
            return false
        }

        return !uriValue.isEmpty
    }
    
    /// Handle a payment link URL via the coordinator
    private func handlePaymentLink(_ paymentLink: String) {
        coordinator.showPayment(paymentLink: paymentLink)
    }
}
