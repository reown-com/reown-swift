import Combine
import SwiftUI

public let DesktopWallet_walletId = "desktopWallet"

public class Store: ObservableObject {
    public static var shared: Store = .init()
    
    @Published public var isModalShown: Bool = false
    @Published public var retryShown = false

    @Published var SIWEFallbackState: Bool = false {
        didSet {
            if SIWEFallbackState == true {
                retryShown = false
            }
        }
    }

    @Published var identity: Identity?
    @Published var balance: Double?
    
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
    
    @Published public var currentWallet: Wallet? = nil
    @Published public var wallets: Set<Wallet> = []
    @Published public var featuredWallets: [Wallet] = [] {
        didSet { prefetchImages(for: featuredWallets) }
    }
    @Published public var searchedWallets: [Wallet] = []
    @Published public var customWallets: [Wallet] = [] {
        didSet { prefetchImages(for: customWallets) }
    }
    @Published public var installedWalletIds: [String] = []

    var totalNumberOfWallets: Int = 0
    var currentPage: Int = 0
    var totalPages: Int = .max
    public var walletMetdata: [WalletMetadata] = []
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
    
    public var cancellables: Set<AnyCancellable> = []
}

extension Store {
    public var sortedWalletsPublisher: AnyPublisher<[Wallet], Never> {
        Publishers
            .CombineLatest4($customWallets, $featuredWallets, $wallets, $installedWalletIds)
            .receive(on: DispatchQueue.main)
            .compactMap { [weak self] _ in self?.sortedWallets }
            .eraseToAnyPublisher()
    }
    
    public var sortedWallets: [Wallet] {
        /// CustomWallets must be added first to preserve their data and not get overwritten.
        /// Then, FeaturedWallets are added to the set.
        /// Finally, RecentWallets are added to the set, and if there are any duplicates, the lastTimeUsed property is updated.
        let unsortedWallets = Set(customWallets).union(featuredWallets).union(recentWallets).map { featuredWallet in
            
            var featuredWallet = featuredWallet
            if let recent = recentWallets.first(where: { $0.id == featuredWallet.id }) {
                featuredWallet.lastTimeUsed = recent.lastTimeUsed
            }
            
            if featuredWallet.isInstalled, !installedWalletIds.contains(featuredWallet.id) {
                installedWalletIds.append(featuredWallet.id)
            }
            
            return featuredWallet
        }
        return sortWallets(unsortedWallets)
    }
    
    public var sortedSearchWallets: [Wallet] {
        sortWallets(searchedWallets)
    }
    
    private func sortWallets(_ wallets: [Wallet]) -> [Wallet] {
        let recommended = AppKit.config.recommendedWalletIds
        let installed = installedWalletIds
        let distantPast = Date.distantPast
        
        return wallets
            .sorted(by: { $0.order < $1.order } )
            .sorted(by: {
                if installed.contains($0.id) && installed.contains($1.id) {
                    return installed.firstIndex(of: $0.id)! < installed.firstIndex(of: $1.id)!
                } else {
                    return installed.contains($0.id) && !installed.contains($1.id)
                }
            } )
            .sorted(by: {
                if recommended.contains($0.id) && recommended.contains($1.id) {
                    return recommended.firstIndex(of: $0.id)! < recommended.firstIndex(of: $1.id)!
                } else {
                    return recommended.contains($0.id) && !recommended.contains($1.id)
                }
            } )
            .sorted(by: { $0.lastTimeUsed ?? distantPast > $1.lastTimeUsed ?? distantPast } )
            .sorted(by: { $0.id == DesktopWallet_walletId && $1.id != DesktopWallet_walletId } )
    }
    
    private func prefetchImages(for wallets: [Wallet]) {
        // Collect unique URLs we don't already have cached
        let urls = Array(
            Set(wallets.compactMap { $0.appIconUrl })
        ).filter { ImageCache[$0] == nil }

        guard !urls.isEmpty else { return }

        // Prefetch in the background
        Task.detached(priority: .background) {
            let session = URLSession(configuration: .default)

            await withTaskGroup(of: Void.self) { group in
                for url in urls {
                    group.addTask {
                        do {
                            let (data, _) = try await session.data(from: url)
                            guard let uiImage = UIImage(data: data) else { return }
                            let image = Image(uiImage: uiImage)
                            await MainActor.run { ImageCache[url] = image }
                        } catch {
                            // You can log here if you want
                            print("Prefetch failed for \(url): \(error)")
                        }
                    }
                }
            }
        }
    }
}

public struct W3MAccount: Codable {
    public let address: String
    public let chain: Blockchain
    
    public init(address: String, chain: Blockchain) {
        self.address = address
        self.chain = chain
    }
}

extension W3MAccount {
    
    public init?(from session: Session) {
        guard let account = session.accounts.first else {
            return nil
        }
        
        self.init(from: account)
    }
    
    public init?(from account: Account) {
        self.init(address: account.address, chain: account.blockchain)
    }
    
    static let stub: Self = .init(
        address: "0x5c8877144d858e41d8c33f5baa7e67a5e0027e37",
        chain: Blockchain(namespace: "eip155", reference: "56")!
    )

    public func account() -> Account? {
        return Account(blockchain: chain, address: address)
    }
}
