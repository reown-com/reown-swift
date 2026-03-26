import Foundation
import SwiftUI
import WalletConnectUtils

#if canImport(UIKit)
import UIKit
#endif

/// AppKit instance wrapper
///
/// ```Swift
/// let metadata = AppMetadata(
///     name: "Swift dapp",
///     description: "dapp",
///     url: "dapp.wallet.connect",
///     icons:  ["https://my_icon.com/1"]
/// )
/// AppKit.configure(projectId: PROJECT_ID, metadata: metadata)
/// AppKit.instance.getSessions()
/// ```
public class AppKit {
    /// Primary session topic for wallet connection
    public static var primarySessionTopic: String? {
        get { UserDefaults.standard.string(forKey: "appkit.primarySessionTopic") }
        set { UserDefaults.standard.set(newValue, forKey: "appkit.primarySessionTopic") }
    }

    private static let configQueue = DispatchQueue(label: "com.walletconnect..appkit.config", attributes: .concurrent)

    /// AppKit client instance
    public static var instance: AppKitClient = {
        guard let config = AppKit.config else {
            fatalError("Error - you must call AppKit.configure(_:) before accessing the shared instance.")
        }
        let client = AppKitClient(
            logger: ConsoleLogger(prefix: "📜", loggingLevel: .off),
            signClient: Sign.instance,
            pairingClient: Pair.instance as! (PairingClientProtocol & PairingInteracting & PairingRegisterer),
            store: .shared,
            analyticsService: .shared
        )
        
        let store = Store.shared
        
        if let primarySessionTopic,
           let session = client.getSessions().first(where: {
               $0.topic == primarySessionTopic
           })
        {
            store.session = session
            store.account = .init(from: session)
        } else {
            AccountStorage.clear()
        }

        return client
    }()
    
    struct Config {
        static let sdkVersion: String = {
            return EnvironmentInfo.sdkName                    
        }()

        static let sdkType = "appkit"
        
        let projectId: String
        var metadata: AppMetadata
        let crypto: CryptoProvider
        var sessionParams: SessionParams
        var authRequestParams: AuthRequestParams?

        let includeWebWallets: Bool
        let recommendedWalletIds: [String]
        let includedWalletIds: [String]
        let excludedWalletIds: [String]
        let queryableWalletSchemes: [String]
        let customWallets: [Wallet]

        let onError: (Error) -> Void

    }
    
    private static var _config: Config!
    
    static var config: Config! {
        get {
            return configQueue.sync { _config }
        }
        set {
            configQueue.async(flags: .barrier) { _config = newValue }
        }
    }
    
    private(set) static var viewModel: Web3ModalViewModel!

    private init() {}

    /// Wallet instance wallet config method.
    /// - Parameters:
    ///   - metadata: App metadata
    public static func configure(
        projectId: String,
        metadata: AppMetadata,
        crypto: CryptoProvider,
        sessionParams: SessionParams = .default,
        authRequestParams: AuthRequestParams?,
        includeWebWallets: Bool = true,
        recommendedWalletIds: [String] = [],
        includedWalletIds: [String] = [],
        excludedWalletIds: [String] = [],
        queryableWalletSchemes: [String] = [],
        customWallets: [Wallet] = [],
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        Pair.configure(metadata: metadata)
        
        AppKit.config = AppKit.Config(
            projectId: projectId,
            metadata: metadata,
            crypto: crypto,
            sessionParams: sessionParams,
            authRequestParams: authRequestParams,
            includeWebWallets: includeWebWallets,
            recommendedWalletIds: recommendedWalletIds,
            includedWalletIds: includedWalletIds,
            excludedWalletIds: excludedWalletIds,
            queryableWalletSchemes: queryableWalletSchemes,
            customWallets: customWallets,
            onError: onError
        )

        Sign.configure(crypto: crypto)

        let store = Store.shared
        let router = Router()
        let w3mApiInteractor = W3MAPIInteractor(store: store)
        let signInteractor = SignInteractor(store: store)
        let blockchainApiInteractor = BlockchainAPIInteractor(store: store)
        
        store.customWallets = customWallets
        
        AppKit.viewModel = Web3ModalViewModel(
            router: router,
            store: store,
            w3mApiInteractor: w3mApiInteractor,
            signInteractor: signInteractor,
            blockchainApiInteractor: blockchainApiInteractor,
            supportsAuthenticatedSession: (config.authRequestParams != nil)
        )
        
        Task(priority: .background) {
            try? await w3mApiInteractor.fetchAllWalletMetadata()
            try? await w3mApiInteractor.fetchFeaturedWallets()
            try? await w3mApiInteractor.fetchAllWalletsFirstPage()
            try? await w3mApiInteractor.prefetchChainImages()
        }
    }
    
    public func currentSession() -> Session? {
        Store.shared.session
    }
    
    public func currentAccount() -> W3MAccount? {
        Store.shared.account
    }
    
    @MainActor
    public static func selectSessionAccount(account: WalletConnectUtils.Account?) {
        let store = Store.shared
        
        guard let account else {
            clearCurrentAccount()
            return
        }
        
        if let session = instance.getSessions().first(where: { session in
            session.accounts.contains(account)
        }) {
            store.session = session
            store.account = .init(from: session)
            selectChain(account.blockchain)
        } else {
            print("Cannot select account that's not in a connected session. Setting to nil")
            clearCurrentAccount()
        }
    }
    
    public static func setCurrentWallet(_ wallet: Wallet?) {
        Store.shared.currentWallet = wallet
    }
    
    @MainActor
    public static func selectChain(_ blockchain: Blockchain) {
        guard let matchingChain = ChainPresets.ethChains.first(where: {
            $0.chainNamespace == blockchain.namespace &&
            $0.chainReference == blockchain.reference
        }) else {
            print("No matching chain found for the provided blockchain: \(blockchain.absoluteString)")
            return
        }
        
        Store.shared.selectedChain = matchingChain
    }
    
    @MainActor
    public static func clearCurrentAccount() {
        Store.shared.account = nil
        Store.shared.session = nil
    }
    
    public static func set(sessionParams: SessionParams) {
        configQueue.async(flags: .barrier) {
            _config.sessionParams = sessionParams
        }
    }
    
    public static func set(authRequestParams: AuthRequestParams) {
        configQueue.async(flags: .barrier) {
            _config.authRequestParams = authRequestParams
        }
    }
    
    public static func set(authRequestParams: AuthRequestParams?) {
        AppKit.config.authRequestParams = authRequestParams
    }
    
    public static func getAuthRequestParams() -> AuthRequestParams? {
        AppKit.config.authRequestParams
    }
}

#if canImport(UIKit)

public extension AppKit {
    static func presentSelectChain(from presentingViewController: UIViewController? = nil) {
        guard let vc = presentingViewController ?? topViewController() else {
            assertionFailure("No controller found for presenting modal")
            return
        }
        
        _ = AppKit.instance
        
        AppKit.viewModel.router.setRoute(Router.NetworkSwitchSubpage.selectChain)
        
        Store.shared.connecting = true
        
        let modal = Web3ModalSheetController(router: AppKit.viewModel.router)
        vc.present(modal, animated: true)
    }
    
    static func present(from presentingViewController: UIViewController? = nil, app: Wallet? = nil) {
        guard let vc = presentingViewController ?? topViewController() else {
            assertionFailure("No controller found for presenting modal")
            return
        }
        
        _ = AppKit.instance
        
        Store.shared.connecting = true
        
        if var wallet = app {
            wallet.lastTimeUsed = Date()
            Store.shared.recentWallets.append(wallet)
            AppKit.setCurrentWallet(app)
            AppKit.viewModel.router.setRoute(Router.ConnectingSubpage.walletDetail(wallet))
        } else {
            AppKit.setCurrentWallet(nil)
            AppKit.viewModel.router.setRoute(Router.ConnectingSubpage.connectWallet)
        }

        let modal = Web3ModalSheetController(router: AppKit.viewModel.router)
        vc.present(modal, animated: true)
    }
    
    static func showConnectingWallet(_ app: Wallet) {
        AppKit.viewModel.router.setRoute(Router.ConnectingSubpage.walletDetail(app))
    }
    
    private static func topViewController(_ base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? UIApplication
            .shared
            .connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .last { $0.isKeyWindow }?
            .rootViewController
        
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }
        
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        
        return base
    }
}

#elseif canImport(AppKit)

import AppKit

public extension AppKit {
    static func present(from presentingViewController: NSViewController? = nil) {
        let modal = Web3ModalSheetController()
        presentingViewController!.presentAsModalWindow(modal)
    }
}

#endif

public struct SessionParams {
    public let requiredNamespaces: [String: ProposalNamespace]
    public let optionalNamespaces: [String: ProposalNamespace]?
    public let sessionProperties: [String: String]?
    
    /// Initialize SessionParams with namespaces that will be treated as optional
    /// to improve connection compatibility between dApps and wallets.
    /// - Parameters:
    ///   - namespaces: The namespaces for the session (will be treated as optional)
    ///   - sessionProperties: Optional session properties
    public init(
        namespaces: [String: ProposalNamespace],
        sessionProperties: [String: String]? = nil
    ) {
        self.requiredNamespaces = [:]
        self.optionalNamespaces = namespaces
        self.sessionProperties = sessionProperties
    }
    
    /// Initialize SessionParams with required and optional namespaces
    /// - Parameters:
    ///   - requiredNamespaces: Required namespaces for the session (deprecated - will be moved to optional namespaces)
    ///   - optionalNamespaces: Optional namespaces for the session
    ///   - sessionProperties: Optional session properties
    @available(*, deprecated, message: "requiredNamespaces parameter is deprecated. All namespaces will be treated as optional to improve connection compatibility. Use init(namespaces:sessionProperties:) instead.")
    public init(requiredNamespaces: [String: ProposalNamespace], optionalNamespaces: [String: ProposalNamespace]? = nil, sessionProperties: [String: String]? = nil) {
        self.requiredNamespaces = requiredNamespaces
        self.optionalNamespaces = optionalNamespaces
        self.sessionProperties = sessionProperties
    }
    
    public static let `default`: Self = {
        let methods: Set<String> = Set(EthUtils.ethMethods)
        let events: Set<String> = ["chainChanged", "accountsChanged"]
        let blockchains = ChainPresets.ethChains.map(\.id).compactMap(Blockchain.init)

        let namespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: blockchains,
                methods: methods,
                events: events
            ),
            "solana": ProposalNamespace(
                chains: [
                    Blockchain("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")!
                ],
                methods: [
                    "solana_signMessage",
                    "solana_signTransaction"
                ], events: []
            )
        ]

       
        return SessionParams(
            namespaces: namespaces,
            sessionProperties: nil
        )
    }()
}
