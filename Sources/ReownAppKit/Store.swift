import Combine
import SwiftUI

public enum ConnectionProviderType {
    case wc
    case cb
}

public class Store: ObservableObject {
    public static var shared: Store = .init()
    
    @Published var isModalShown: Bool = false
    @Published var retryShown = false

    @Published var SIWEFallbackState: Bool = false {
        didSet {
            if SIWEFallbackState == true {
                retryShown = false
            }
        }
    }

    @Published var identity: Identity?
    @Published var balance: Double?
    
    @Published public var connectedWith: ConnectionProviderType?
    @Published public var connecting: Bool = false
    @Published public var account: W3MAccount? {
        didSet {
            let matchingChain = ChainPresets.ethChains.first(where: {
                $0.chainNamespace == account?.chain.namespace && $0.chainReference == account?.chain.reference
            })
            
            Store.shared.selectedChain = matchingChain
            
            AccountStorage.save(account)
        }
    }
    // WalletConnect specific
    @Published public var session: Session?
    @Published public var uri: WalletConnectURI?
    
    @Published var wallets: Set<Wallet> = []
    @Published var featuredWallets: [Wallet] = []
    @Published var searchedWallets: [Wallet] = []
    @Published var customWallets: [Wallet] = []
    
    var totalNumberOfWallets: Int = 0
    var currentPage: Int = 0
    var totalPages: Int = .max
    var walletImages: [String: UIImage] = [:]
    var installedWalletIds: [String] = []
    var queryableWalletSchemes: [String] = []
    var siweRequestId: RPCID? = nil
    var siweMessage: String? = nil

    var recentWallets: [Wallet] {
        get {
            RecentWalletsStorage.loadRecentWallets()
        }
        set(newValue) {
            RecentWalletsStorage.saveRecentWallets(newValue)
        }
    }
    
    @Published public var selectedChain: Chain?
    @Published var chainImages: [String: UIImage] = [:]
    
    @Published var toast: Toast? = nil
}

public struct W3MAccount: Codable {
    public let address: String
    public let chain: Blockchain
}

extension W3MAccount {
    
    init?(from session: Session) {
        guard let account = session.accounts.first else {
            return nil
        }
        
        self.init(from: account)
    }
    
    init?(from account: Account) {
        self.init(address: account.address, chain: account.blockchain)
    }
    
    static let stub: Self = .init(
        address: "0x5c8877144d858e41d8c33f5baa7e67a5e0027e37",
        chain: Blockchain(namespace: "eip155", reference: "56")!
    )

    func account() -> Account? {
        return Account(blockchain: chain, address: address)
    }
}
