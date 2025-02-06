import Combine
import SwiftUI

final class NetworkDetailViewModel: ObservableObject {
    enum Event {
        case onAppear
        case didTapRetry
    }
    
    @Published var switchFailed: Bool = false
    var triedAddingChain: Bool = false
    
    private var disposeBag = Set<AnyCancellable>()
    
    var chain: Chain
    let router: Router
    let store: Store
    
    
    init(
        chain: Chain,
        router: Router,
        store: Store = .shared
    ) {
        
        self.chain = chain
        self.router = router
        self.store = store
    
        AppKit.instance.sessionEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] event, _, _ in
                switch event.name {
                case "chainChanged":
                    guard let chainReference = try? event.data.get(Int.self) else {
                        return
                    }
                    
                    self.store.selectedChain = ChainPresets.ethChains.first(where: { $0.chainReference == String(chainReference) })
                    self.router.setRoute(Router.AccountSubpage.profile)
                    
                case "accountsChanged":
                    
                    guard let account = try? event.data.get([String].self) else {
                        return
                    }
                    
                    let chainReference = account[0].split(separator: ":")[1]
                    
                    self.store.selectedChain = ChainPresets.ethChains.first(where: { $0.chainReference == String(chainReference) })
                    self.router.setRoute(Router.AccountSubpage.profile)
                default:
                    break
                }
            }
            .store(in: &disposeBag)
        
        AppKit.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] response in
                
                switch response.result {
                case .response:
                    
                    print("Switch/Add chain success switching to: \(chain.chainName)")
                    
                    self.store.selectedChain = chain
                    self.router.setRoute(Router.AccountSubpage.profile)
                case let .error(error):
                    
                    if error.message.contains("4001") {
                        // User declined
                        self.switchFailed = true
                        return
                    }
                    
                    if !self.triedAddingChain {
                        guard let from = store.selectedChain else {
                            return
                        }
                        
                        self.triedAddingChain = true
                        Task {
                            try? await self.addEthChain(from: from, to: chain)
                        }
                    } else {
                        self.switchFailed = true
                    }
                }
            }
            .store(in: &disposeBag)
    }
    
    func handle(_ event: Event) {
        switch event {
        case .onAppear, .didTapRetry:
            triedAddingChain = false
            switchFailed = false
            
            Task { @MainActor in
                // Switch chain
                await switchChain(chain)
            }
        }
    }
    
    @MainActor
    func switchChain(_ to: Chain) async {
        guard let from = store.selectedChain else { return }
        
        do {
            try await switchEthChain(from: from, to: to)
        } catch {
            AppKit.config.onError(error)
        }
        
        guard let session = store.session else { return }
        
        if
            let urlString = session.peer.redirect?.native ?? session.peer.redirect?.universal,
            let url = URL(string: urlString)
        {
            DispatchQueue.main.async {
                self.router.openURL(url)
            }
        }
    }
    
    @MainActor
    private func switchEthChain(
        from: Chain,
        to: Chain
    ) async throws {
        guard let chainIdNumber = Int(to.chainReference) else { return }
        
        switch store.connectedWith {
        case .wc:
            
            let chainHex = String(format: "%X", chainIdNumber)
            
            guard let session = store.session else { return }
            
            try await AppKit.instance.request(params:
                    .init(
                        topic: session.topic,
                        method: EthUtils.walletSwitchEthChain,
                        params: AnyCodable([AnyCodable(ChainSwitchParams(chainId: "0x\(chainHex)"))]),
                        chainId: .init(from.id)!
                    )
            )
//        case .cb:
//            try await AppKit.instance.request(.wallet_switchEthereumChain(chainId: to.chainReference))
        case .none:
            break
        }
    }

    @MainActor
    private func addEthChain(
        from: Chain,
        to: Chain
    ) async throws {
        
        guard let addChainParams = createAddEthChainParams(chain: to) else {
            return
        }
        
        switch store.connectedWith {
        case .wc:
            
            guard let session = store.session else { return }
            
            try await AppKit.instance.request(params:
                .init(
                    topic: session.topic,
                    method: EthUtils.walletAddEthChain,
                    params: AnyCodable([AnyCodable(addChainParams)]),
                    chainId: .init(from.id)!
                )
            )
//        case .cb:
//            try await AppKit.instance.request(
//                .wallet_addEthereumChain(
//                    chainId: addChainParams.chainId,
//                    blockExplorerUrls: addChainParams.blockExplorerUrls,
//                     chainName: addChainParams.chainName,
//                     iconUrls: addChainParams.iconUrls,
//                    nativeCurrency: .init(
//                        name: addChainParams.nativeCurrency.name,
//                        symbol: addChainParams.nativeCurrency.symbol,
//                        decimals: addChainParams.nativeCurrency.decimals
//                    ),
//                     rpcUrls: addChainParams.rpcUrls
//                 ))
        case .none:
            break
        }
    }

    func createAddEthChainParams(chain: Chain) -> ChainAddParams? {
        guard let chainIdNumber = Int(chain.chainReference) else { return nil }
        
        let chainHex = String(format: "%X", chainIdNumber)
        
        return ChainAddParams(
            chainId: "0x\(chainHex)",
            blockExplorerUrls: [
                chain.blockExplorerUrl
            ],
            chainName: chain.chainName,
            nativeCurrency: .init(
                name: chain.token.name,
                symbol: chain.token.symbol,
                decimals: chain.token.decimal
            ),
            rpcUrls: [
                chain.rpcUrl
            ],
            iconUrls: [
                chain.imageId
            ]
        )
    }
    
    struct ChainAddParams: Codable {
        let chainId: String
        let blockExplorerUrls: [String]
        let chainName: String
        let nativeCurrency: NativeCurrency
        let rpcUrls: [String]
        let iconUrls: [String]
        
        struct NativeCurrency: Codable {
            let name: String
            let symbol: String
            let decimals: Int
        }
    }
    
    struct ChainSwitchParams: Codable {
        let chainId: String
    }
}
