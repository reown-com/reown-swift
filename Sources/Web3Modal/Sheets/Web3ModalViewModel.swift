import Combine
import SwiftUI

public enum SIWEAuthenticationError: Error {
    case requestRejected
    case messageVerificationFailed
}

class Web3ModalViewModel: ObservableObject {
    private(set) var router: Router
    private(set) var store: Store
    private(set) var w3mApiInteractor: W3MAPIInteractor
    private(set) var signInteractor: SignInteractor
    private(set) var blockchainApiInteractor: BlockchainAPIInteractor
    private let supportsAuthenticatedSession: Bool

    private var disposeBag = Set<AnyCancellable>()

    init(
        router: Router,
        store: Store,
        w3mApiInteractor: W3MAPIInteractor,
        signInteractor: SignInteractor,
        blockchainApiInteractor: BlockchainAPIInteractor,
        supportsAuthenticatedSession: Bool
    ) {
        self.router = router
        self.store = store
        self.w3mApiInteractor = w3mApiInteractor
        self.signInteractor = signInteractor
        self.blockchainApiInteractor = blockchainApiInteractor
        self.supportsAuthenticatedSession = supportsAuthenticatedSession

        setupSIWEFallback()

        Web3Modal.instance.sessionEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event, _, _ in
                switch event.name {
                case "chainChanged":
                    guard let chainReference = try? event.data.get(Int.self) else {
                        return
                    }

                    Store.shared.selectedChain = ChainPresets.ethChains.first(where: { $0.chainReference == String(chainReference) })

                case "accountsChanged":

                    guard let account = try? event.data.get([String].self) else {
                        return
                    }

                    let chainReference = account[0].split(separator: ":")[1]

                    Store.shared.selectedChain = ChainPresets.ethChains.first(where: { $0.chainReference == String(chainReference) })
                default:
                    break
                }
            }
            .store(in: &disposeBag)

        signInteractor.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self = self else { return }
                self.handleNewSession(session: session)
                if supportsAuthenticatedSession {
                    self.handleSIWEFallback()
                } else {
                    self.routeToProfile()
                }
            }
            .store(in: &disposeBag)


        signInteractor.authResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                switch response.result {
                case .success(let (session, _)):
                    if let session = session {
                        self?.handleNewSession(session: session)
                        self?.routeToProfile()
                    }
                case .failure(let error):
                    if error == .methodUnsupported {
                        break
                    } else {
                        store.toast = .init(style: .error, message: "Authentication error: \(error.localizedDescription)")
                        Web3Modal.config.onError(error)
                        self?.store.retryShown = true
                    }
                }
            }
            .store(in: &disposeBag)



        signInteractor.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { topic, _ in
                
                if store.session?.topic == topic {
                    store.session = nil
                    store.account = nil
                }
                router.setRoute(Router.ConnectingSubpage.connectWallet)
            }
            .store(in: &disposeBag)
        
        signInteractor.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { sessions in
                
                if sessions.isEmpty {
                    DispatchQueue.main.async {
                        store.session = nil
                        store.account = nil
                        router.setRoute(Router.ConnectingSubpage.connectWallet)
                    }
                }
            }
            .store(in: &disposeBag)
        
        Task {
            try? await signInteractor.connect(walletUniversalLink: nil)
        }
    }
    
    func fetchIdentity() {
        Task { @MainActor in
            do {
                try await blockchainApiInteractor.getIdentity()
            } catch {
                store.toast = .init(style: .error, message: "Network error")
                Web3Modal.config.onError(error)
            }
        }
    }
    
    func fetchBalance() {
        Task { @MainActor in
            do {
                try await blockchainApiInteractor.getBalance()
            } catch {
                store.toast = .init(style: .error, message: "Network error")
                Web3Modal.config.onError(error)
            }
        }
    }

    private func handleNewSession(session: Session) {
        store.connectedWith = .wc
        store.account = .init(from: session)
        store.session = session

        if
            let blockchain = session.accounts.first?.blockchain,
            let matchingChain = ChainPresets.ethChains.first(where: { $0.chainNamespace == blockchain.namespace && $0.chainReference == blockchain.reference })
        {
            store.selectedChain = matchingChain
        }

        fetchIdentity()

    }

    private func routeToProfile() {
        router.setRoute(Router.AccountSubpage.profile)
        withAnimation {
            store.isModalShown = false
        }
    }

    private func handleSIWEFallback() {
        store.SIWEFallbackState = true
    }


    func getChains() -> [Chain] {
        guard let namespaces = store.session?.namespaces.values else {
            return []
        }
        
        var chains = namespaces
            .compactMap { $0.chains }
            .flatMap { $0 }
            .filter { chain in
                isChainIdCAIP2Compliant(chainId: chain.absoluteString)
            }
        
        if let requiredNamespaces = store.session?.requiredNamespaces.values {
            let requiredChains = requiredNamespaces
                .compactMap { $0.chains }
                .flatMap { $0 }
                .filter { chain in
                    isChainIdCAIP2Compliant(chainId: chain.absoluteString)
                }
            
            chains.append(contentsOf: requiredChains)
        }
        
        return chains
            .compactMap { chain in
                ChainPresets.ethChains.first(where: { chain.reference == $0.chainReference && chain.namespace == $0.chainNamespace })
            }
    }
    
    func getMethods() -> [String] {
        guard let session = store.session else {
            return []
        }
        
        let methods = session.namespaces.values
            .compactMap { $0.methods }
            .flatMap { $0 }
        
        let requiredMethods = session.requiredNamespaces.values
            .compactMap { $0.methods }
            .flatMap { $0 }
        
        return (methods + requiredMethods)
    }
    
    func isChainIdCAIP2Compliant(chainId: String) -> Bool {
        let elements = chainId.split(separator: ":")
        guard elements.count == 2 else { return false }

        let namespace = String(elements[0])
        let reference = String(elements[1])
        
        return isNamespaceRegexCompliant(key: namespace) && referenceRegex.matches(in: reference, options: [], range: NSRange(location: 0, length: reference.utf16.count)).count > 0
    }

    private let referenceRegex = try! NSRegularExpression(pattern: "^[-_a-zA-Z0-9]{1,32}$")

    // For namespace key validation reference check CAIP-2: https://github.com/ChainAgnostic/CAIPs/blob/master/CAIPs/caip-2.md#syntax
    func isNamespaceRegexCompliant(key: String) -> Bool {
        return namespaceRegex.matches(in: key, options: [], range: NSRange(location: 0, length: key.utf16.count)).count > 0
    }

    private let namespaceRegex = try! NSRegularExpression(pattern: "^[-a-z0-9]{3,8}$")

    private func setupSIWEFallback() {
        Sign.instance.sessionResponsePublisher.sink { [weak self] response in
            if response.id == self?.store.siweRequestId {
                switch response.result {
                case .response(let result):
                    guard let signature = try? result.get(String.self),
                          let siweMessage = self?.store.siweMessage,
                          let account = self?.store.account?.account() else { return }

                    Task { [weak self] in
                        do {
                            try await Sign.instance.verifySIWE(signature: signature, message: siweMessage, address: account.address, chainId: account.blockchainIdentifier)

                            guard let self = self else { return }

                            Web3Modal.instance.SIWEAuthenticationPublisherSubject.send(.success((siweMessage, signature)))

                            DispatchQueue.main.async {
                                self.router.setRoute(Router.AccountSubpage.profile)
                                self.store.isModalShown = false
                            }
                        } catch {
                            guard let self = self else { return }

                            Web3Modal.instance.SIWEAuthenticationPublisherSubject.send(Result.failure(
                                .messageVerificationFailed))
                            DispatchQueue.main.async {
                                self.store.toast = .init(style: .error, message: error.localizedDescription)
                                guard let topic = self.store.session?.topic else { return }
                                Task {try await Web3Modal.instance.disconnect(topic: topic)}

                            }
                        }
                    }
                case .error(let error):
                    DispatchQueue.main.async {
                        Web3Modal.instance.SIWEAuthenticationPublisherSubject.send(Result.failure(
                            .requestRejected))
                        guard let self = self else { return }
                        self.store.SIWEFallbackState = false
                        guard let topic = self.store.session?.topic else { return }
                        Task {try await Web3Modal.instance.disconnect(topic: topic)}
                    }
                }
            }
        }.store(in: &disposeBag)
    }
}
