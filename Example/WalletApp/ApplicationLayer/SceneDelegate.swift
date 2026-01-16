import SafariServices
import UIKit
import ReownWalletKit
import WalletConnectSign
import WalletConnectPay
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
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                // Check for new `pay` query parameter (URL-encoded payment link)
                if let encodedPaymentLink = queryItems.first(where: { $0.name == "pay" })?.value,
                   let decodedPaymentLink = encodedPaymentLink.removingPercentEncoding {
                    pendingPaymentLink = decodedPaymentLink
                }
                // Legacy: Check for walletconnectpay host with paymentId
                else if url.host == "walletconnectpay",
                        let paymentId = queryItems.first(where: { $0.name == "paymentId" })?.value {
                    pendingPaymentLink = "walletapp://walletconnectpay?paymentId=\(paymentId)"
                }
            }
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
                print("Error initializing WalletConnectURI: \(error.localizedDescription)")
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
            // Delay slightly to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handlePaymentLink(paymentLink)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else { return }

        let url = context.url

        // Check for payment deep link
        // New format: walletapp://?uri={pairing_uri}&pay={URL_ENCODED_PAYMENT_LINK}
        // Legacy format: walletapp://walletconnectpay?paymentId=<id>
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            // Check for new `pay` query parameter (URL-encoded payment link)
            if let encodedPaymentLink = queryItems.first(where: { $0.name == "pay" })?.value,
               let decodedPaymentLink = encodedPaymentLink.removingPercentEncoding {
                handlePaymentLink(decodedPaymentLink)
                // If both `pay` and `uri` are present, also handle pairing
                // This allows backwards compatibility where old wallets use uri for Sign flow
                if queryItems.contains(where: { $0.name == "uri" }) {
                    // Continue to pairing flow below
                } else {
                    return
                }
            }
            // Legacy: Check for walletconnectpay host with paymentId
            else if url.host == "walletconnectpay",
                    let paymentId = queryItems.first(where: { $0.name == "paymentId" })?.value {
                handlePaymentLink("walletapp://walletconnectpay?paymentId=\(paymentId)")
                return
            }
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

        WalletKit.configure(metadata: metadata, crypto: DefaultCryptoProvider(), environment: BuildConfiguration.shared.apnsEnvironment, pimlicoApiKey: InputConfig.pimlicoApiKey)

        // Configure Pay client
        if let payApiKey = InputConfig.payApiKey {
            #if DEBUG
            WalletConnectPay.configure(projectId: InputConfig.projectId, apiKey: payApiKey, logging: true)
            #else
            WalletConnectPay.configure(projectId: InputConfig.projectId, apiKey: payApiKey)
            #endif
        }
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
    
    /// Handle a full payment link URL (new format)
    /// - Parameter paymentLink: The payment link URL (e.g., "https://pay.walletconnect.com/?pid=pay_123"
    ///   or legacy "walletapp://walletconnectpay?paymentId=<id>")
    private func handlePaymentLink(_ paymentLink: String) {
        guard let topController = window?.rootViewController?.topController else {
            return
        }

        // Get wallet account from storage
        guard let account = AccountStorage(defaults: .standard).importAccount else {
            AlertPresenter.present(message: "No account found. Please import an account first.", type: .error)
            return
        }

        // Get accounts in CAIP-10 format for multiple chains
        let address = account.account.address
        let accounts = [
            "eip155:1:\(address)",      // Ethereum Mainnet
            "eip155:137:\(address)",    // Polygon
            "eip155:8453:\(address)"    // Base
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

