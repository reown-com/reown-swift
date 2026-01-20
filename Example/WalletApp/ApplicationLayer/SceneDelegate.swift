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

        // Check for payment deep link on cold start
        // New format: walletapp://?uri={pairing_uri}&pay={URL_ENCODED_PAYMENT_LINK}
        // Legacy format: walletapp://walletconnectpay?paymentId=<id>
        var pendingPaymentLink: String?
        if let urlContext = connectionOptions.urlContexts.first {
            let url = urlContext.url
            print("🔗 [PayDeeplink] Cold start - Received URL: \(url.absoluteString)")
            print("🔗 [PayDeeplink] URL scheme: \(url.scheme ?? "nil")")
            print("🔗 [PayDeeplink] URL host: \(url.host ?? "nil")")
            print("🔗 [PayDeeplink] URL path: \(url.path)")
            print("🔗 [PayDeeplink] URL query: \(url.query ?? "nil")")

            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                print("🔗 [PayDeeplink] URLComponents created successfully")
                if let queryItems = components.queryItems {
                    print("🔗 [PayDeeplink] Query items count: \(queryItems.count)")
                    for item in queryItems {
                        print("🔗 [PayDeeplink] Query item: \(item.name) = \(item.value ?? "nil")")
                    }

                    // Check for `uri` parameter which may contain embedded `pay` param
                    // Pass the full WC URI to Yttrium - it handles extraction internally
                    if let uriValue = queryItems.first(where: { $0.name == "uri" })?.value,
                       wcUriContainsPayParam(uriValue) {
                        print("🔗 [PayDeeplink] Found 'uri' param with embedded 'pay', passing to Yttrium: \(uriValue)")
                        pendingPaymentLink = uriValue
                    }
                    // Legacy: Check for walletconnectpay host with paymentId
                    else if url.host == "walletconnectpay",
                            let paymentId = queryItems.first(where: { $0.name == "paymentId" })?.value {
                        print("🔗 [PayDeeplink] Legacy format - paymentId: \(paymentId)")
                        pendingPaymentLink = "walletapp://walletconnectpay?paymentId=\(paymentId)"
                    } else {
                        print("🔗 [PayDeeplink] No 'pay' param found, host is: \(url.host ?? "nil")")
                    }
                } else {
                    print("🔗 [PayDeeplink] No query items found")
                }
            } else {
                print("🔗 [PayDeeplink] ERROR: Failed to create URLComponents")
            }
        } else {
            print("🔗 [PayDeeplink] Cold start - No URL context")
        }

        // Process connection options (only if not a pay-only deeplink)
        // If `pay` param exists but no `uri`, skip pairing
        let hasPayParam = pendingPaymentLink != nil
        let hasUriParam = connectionOptions.urlContexts.first.flatMap { context -> Bool in
            guard let components = URLComponents(url: context.url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else { return false }
            return queryItems.contains(where: { $0.name == "uri" })
        } ?? false

        print("🔗 [PayDeeplink] hasPayParam: \(hasPayParam), hasUriParam: \(hasUriParam)")
        print("🔗 [PayDeeplink] pendingPaymentLink: \(pendingPaymentLink ?? "nil")")

        if !hasPayParam || hasUriParam {
            do {
                // Attempt to initialize WalletConnectURI from connection options
                let uri = try WalletConnectURI(connectionOptions: connectionOptions)
                app.uri = uri
                print("🔗 [PayDeeplink] WalletConnectURI initialized successfully")
            } catch {
                print("🔗 [PayDeeplink] Error initializing WalletConnectURI: \(error.localizedDescription)")
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
                        print("🔗 [PayDeeplink] Error dispatching envelope: \(error.localizedDescription)")
                    }
                    return
                }
            }
        }
        configurators.configure()

        // Handle pending payment after configuration is complete
        if let paymentLink = pendingPaymentLink {
            print("🔗 [PayDeeplink] Will handle payment link after delay: \(paymentLink)")
            // Delay slightly to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("🔗 [PayDeeplink] Now handling payment link: \(paymentLink)")
                self?.handlePaymentLink(paymentLink)
            }
        } else {
            print("🔗 [PayDeeplink] No pending payment link to handle")
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else {
            print("🔗 [PayDeeplink] openURLContexts - No context found")
            return
        }

        let url = context.url
        print("🔗 [PayDeeplink] openURLContexts - Received URL: \(url.absoluteString)")
        print("🔗 [PayDeeplink] URL scheme: \(url.scheme ?? "nil")")
        print("🔗 [PayDeeplink] URL host: \(url.host ?? "nil")")
        print("🔗 [PayDeeplink] URL path: \(url.path)")
        print("🔗 [PayDeeplink] URL query: \(url.query ?? "nil")")

        // Check for payment deep link
        // Format: walletapp://wc?uri={pairing_uri_with_pay_param}
        // The `pay` param is embedded inside the WC URI: wc:topic@2?...&pay={encoded_payment_link}
        // Yttrium handles extraction of the pay param internally
        // Legacy format: walletapp://walletconnectpay?paymentId=<id>
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            print("🔗 [PayDeeplink] URLComponents created successfully")
            if let queryItems = components.queryItems {
                print("🔗 [PayDeeplink] Query items count: \(queryItems.count)")
                for item in queryItems {
                    print("🔗 [PayDeeplink] Query item: \(item.name) = \(item.value ?? "nil")")
                }

                // Check for `uri` parameter which may contain embedded `pay` param
                // Pass the full WC URI to Yttrium - it handles extraction internally
                if let uriValue = queryItems.first(where: { $0.name == "uri" })?.value,
                   wcUriContainsPayParam(uriValue) {
                    print("🔗 [PayDeeplink] Found 'uri' param with embedded 'pay', passing to Yttrium: \(uriValue)")
                    handlePaymentLink(uriValue)
                    // Continue to pairing flow below for backwards compatibility
                    print("🔗 [PayDeeplink] Continuing to pairing flow...")
                }
                // Legacy: Check for walletconnectpay host with paymentId
                else if url.host == "walletconnectpay",
                        let paymentId = queryItems.first(where: { $0.name == "paymentId" })?.value {
                    print("🔗 [PayDeeplink] Legacy format - paymentId: \(paymentId)")
                    handlePaymentLink("walletapp://walletconnectpay?paymentId=\(paymentId)")
                    return
                } else {
                    print("🔗 [PayDeeplink] No 'pay' param found, proceeding to WalletConnect URI handling")
                }
            } else {
                print("🔗 [PayDeeplink] No query items found")
            }
        } else {
            print("🔗 [PayDeeplink] ERROR: Failed to create URLComponents")
        }

        do {
            let uri = try WalletConnectURI(urlContext: context)
            print("🔗 [PayDeeplink] WalletConnectURI created, pairing...")
            Task {
                try await WalletKit.instance.pair(uri: uri)
            }
        } catch {
            print("🔗 [PayDeeplink] WalletConnectURI error: \(error)")
            if case WalletConnectURI.Errors.expired = error {
                AlertPresenter.present(message: error.localizedDescription, type: .error)
            } else {
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let queryItems = components.queryItems,
                      queryItems.contains(where: { $0.name == "wc_ev" }) else {
                    print("🔗 [PayDeeplink] No wc_ev param, returning")
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

    /// Check if a WalletConnect URI contains an embedded `pay` parameter
    /// Uses the unified WalletKit.isPaymentLink() detection
    private func wcUriContainsPayParam(_ wcUri: String) -> Bool {
        let isPayLink = WalletKit.isPaymentLink(wcUri)
        print("🔗 [PayDeeplink] WC URI is payment link: \(isPayLink)")
        return isPayLink
    }
    
    /// Handle a full payment link URL (new format)
    /// - Parameter paymentLink: The payment link URL (e.g., "https://pay.walletconnect.com/?pid=pay_123"
    ///   or legacy "walletapp://walletconnectpay?paymentId=<id>")
    private func handlePaymentLink(_ paymentLink: String) {
        print("🔗 [PayDeeplink] handlePaymentLink called with: \(paymentLink)")

        guard let topController = window?.rootViewController?.topController else {
            print("🔗 [PayDeeplink] ERROR: No top controller available")
            return
        }
        print("🔗 [PayDeeplink] Top controller: \(type(of: topController))")

        // Get wallet account from storage
        guard let account = AccountStorage(defaults: .standard).importAccount else {
            print("🔗 [PayDeeplink] ERROR: No account found in storage")
            AlertPresenter.present(message: "No account found. Please import an account first.", type: .error)
            return
        }
        print("🔗 [PayDeeplink] Account found: \(account.account.address)")

        // Get accounts in CAIP-10 format for multiple chains
        let address = account.account.address
        let accounts = [
            "eip155:1:\(address)",      // Ethereum Mainnet
            "eip155:137:\(address)",    // Polygon
            "eip155:8453:\(address)"    // Base
        ]
        print("🔗 [PayDeeplink] CAIP-10 accounts: \(accounts)")

        print("🔗 [PayDeeplink] Creating PayModule with paymentLink: \(paymentLink)")
        let paymentVC = PayModule.create(
            app: app,
            paymentLink: paymentLink,
            accounts: accounts,
            importAccount: account
        )
        paymentVC.modalPresentationStyle = .overCurrentContext
        paymentVC.view.backgroundColor = .clear
        print("🔗 [PayDeeplink] Presenting PayModule...")
        topController.present(paymentVC, animated: true) {
            print("🔗 [PayDeeplink] PayModule presented successfully")
        }
    }
}

