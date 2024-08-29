import SwiftUI
import Combine

class WalletDetailViewModel: ObservableObject {
    enum Platform: String, CaseIterable, Identifiable {
        case mobile
        case browser
        
        var id: Self { self }
    }
    
    enum Event {
        case onAppear
        case didTapOpen
        case didTapAppStore
        case didTapCopy
    }
    
    let wallet: Wallet
    let router: Router
    let store: Store
    let signInteractor: SignInteractor


    @Published var preferredPlatform: Platform = .mobile
    
    private var disposeBag = Set<AnyCancellable>()
    
    var showToggle: Bool {
        hasWebAppLink && hasMobileLink && wallet.isInstalled != true
    }
    
    var hasWebAppLink: Bool { wallet.webappLink?.isEmpty == false }
    var hasMobileLink: Bool { wallet.mobileLink?.isEmpty == false }
    
    init(
        wallet: Wallet,
        router: Router,
        signInteractor: SignInteractor,
        store: Store = .shared
    ) {
        self.wallet = wallet
        self.router = router
        self.store = store
        self.signInteractor = signInteractor
        preferredPlatform = wallet.mobileLink != nil ? .mobile : .browser
                
        startObserving()
    }
    
    func startObserving() {
        AppKit.instance.sessionRejectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.store.retryShown = true
            }
            .store(in: &disposeBag)
    }

    func cancel() async throws {
        store.SIWEFallbackState = false
        guard let topic = store.session?.topic else { return }
        try await AppKit.instance.disconnect(topic: topic)
    }

    func signSIWE() async throws {
        DispatchQueue.main.async { [weak self] in
            self?.store.SIWEFallbackState = false
        }
        guard let account = store.account?.account(),
              let authRequestParams = AppKit.config.authRequestParams,
        let topic = AppKit.instance.getSessions().first?.topic,
        let chain = AppKit.instance.getSelectedChain(),
        let blockchain = Blockchain(namespace: chain.chainNamespace, reference: chain.chainReference)
        else { return }

        let authPayload = AuthPayload(requestParams: authRequestParams, iat: DefaultIATProvider().iat)
        let siweMessage = try Sign.instance.formatAuthMessage(payload: authPayload, account: account)


        let rpcRequest = try Request(topic: topic, method: "personal_sign", params: AnyCodable([siweMessage, account.address]), chainId: blockchain)
        try await Sign.instance.request(params: rpcRequest)

        store.siweRequestId = rpcRequest.id
        store.siweMessage = siweMessage

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.navigateToWallet(
                wallet: self.wallet,
                preferBrowser: preferredPlatform == .browser
            )
        }
    }

    func handle(_ event: Event) {
        switch event {
        case .didTapCopy:
            UIPasteboard.general.string = store.uri?.absoluteString ?? ""
            store.toast = .init(style: .success, message: "Link copied")
        case .onAppear:
            
            if wallet.alternativeConnectionMethod == nil {
                
                navigateToWalletWithPairingUri(
                    wallet: wallet,
                    preferBrowser: preferredPlatform == .browser
                )
            } else {
                wallet.alternativeConnectionMethod?()
            }
                
            var wallet = wallet
            wallet.lastTimeUsed = Date()
            
            store.recentWallets.append(wallet)
        case .didTapOpen:
                store.retryShown = false
            
            if wallet.alternativeConnectionMethod == nil {
                navigateToWalletWithPairingUri(
                    wallet: wallet,
                    preferBrowser: preferredPlatform == .browser
                )
            } else {
                wallet.alternativeConnectionMethod?()
            }
            
        case .didTapAppStore:
            openAppstore(wallet: wallet)
        }
    }

    private func openAppstore(wallet: Wallet) {
        guard
            let storeLinkString = wallet.appStore,
            let storeLink = URL(string: storeLinkString)
        else { return }
        
        router.openURL(storeLink)
    }

    private func navigateToWallet(wallet: Wallet, preferBrowser: Bool) {
        do {
            let link = preferBrowser ? wallet.webappLink : wallet.mobileLink
            if let url = link?.toURL() {
                router.openURL(url) { success in
                    self.store.toast = .init(style: .error, message: DeeplinkErrors.failedToOpen.localizedDescription)
                }
            } else {
                throw DeeplinkErrors.noWalletLinkFound
            }
        } catch {
            store.toast = .init(style: .error, message: error.localizedDescription)
            AppKit.config.onError(error)
        }
    }

    private func navigateToWalletWithPairingUri(wallet: Wallet, preferBrowser: Bool) {
        do {
            let link = preferBrowser ? wallet.webappLink : wallet.mobileLink
            
            let urlString = try formatNativeUrlString(link)
            if let url = urlString?.toURL() {
                router.openURL(url) { success in
                    self.store.toast = .init(style: .error, message: DeeplinkErrors.failedToOpen.localizedDescription)
                }
            } else {
                throw DeeplinkErrors.noWalletLinkFound
            }
        } catch {
            store.toast = .init(style: .error, message: error.localizedDescription)
            AppKit.config.onError(error)
        }
    }

    enum DeeplinkErrors: LocalizedError {
        case noWalletLinkFound
        case uriNotCreated
        case failedToOpen
        
        var errorDescription: String? {
            switch self {
            case .noWalletLinkFound:
                return NSLocalizedString("No valid link for opening given wallet found", comment: "")
            case .uriNotCreated:
                return NSLocalizedString("Couldn't generate link due to missing connection URI", comment: "")
            case .failedToOpen:
                return NSLocalizedString("Given link couldn't be opened", comment: "")
            }
        }
    }
        
    private func isHttpUrl(url: String) -> Bool {
        return url.hasPrefix("http://") || url.hasPrefix("https://")
    }
        
    private func formatNativeUrlString(_ string: String?) throws -> String? {
        guard let string = string, !string.isEmpty else { return nil }
            
        if isHttpUrl(url: string) {
            return try formatUniversalUrlString(string)
        }
            
        var safeAppUrl = string
        if !safeAppUrl.contains("://") {
            safeAppUrl = safeAppUrl.replacingOccurrences(of: "/", with: "").replacingOccurrences(of: ":", with: "")
            safeAppUrl = "\(safeAppUrl)://"
        }
        
        guard let deeplinkUri = store.uri?.deeplinkUri else {
            throw DeeplinkErrors.uriNotCreated
        }
            
        return "\(safeAppUrl)wc?uri=\(deeplinkUri)"
    }
        
    private func formatUniversalUrlString(_ string: String?) throws -> String? {
        guard let string = string, !string.isEmpty else { return nil }
            
        if !isHttpUrl(url: string) {
            return try formatNativeUrlString(string)
        }
            
        var plainAppUrl = string
        if plainAppUrl.hasSuffix("/") {
            plainAppUrl = String(plainAppUrl.dropLast())
        }
        
        guard let deeplinkUri = store.uri?.deeplinkUri else {
            throw DeeplinkErrors.uriNotCreated
        }
            
        return "\(plainAppUrl)/wc?uri=\(deeplinkUri)"
    }
}

private extension String {
    func toURL() -> URL? {
        URL(string: self)
    }
}
