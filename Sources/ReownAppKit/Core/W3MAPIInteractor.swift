import UIKit

final class W3MAPIInteractor: ObservableObject {
    @Published var isLoading: Bool = false
    
    private let store: Store
    private let uiApplicationWrapper: UIApplicationWrapper
    
    private let entriesPerPage: Int = 40
    
    var totalEntries: Int = 0
        
    init(
        store: Store = .shared,
        uiApplicationWrapper: UIApplicationWrapper = .live
    ) {
        self.store = store
        self.uiApplicationWrapper = uiApplicationWrapper
    }
    
    func fetchWallets(search: String = "") async throws {
        if search.isEmpty {
            if store.currentPage + 1 > store.totalPages {
                return
            }
            
            store.currentPage = min(store.currentPage + 1, store.totalPages)
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        let params = Web3ModalAPI.GetWalletsParams(
            page: search.isEmpty ? store.currentPage : 1,
            entries: search.isEmpty ? entriesPerPage : 100,
            search: search,
            projectId: AppKit.config.projectId,
            metadata: AppKit.config.metadata,
            recommendedIds: AppKit.config.recommendedWalletIds,
            excludedIds: AppKit.config.excludedWalletIds
        )
        
        let httpClient = HTTPNetworkClient(host: "api.web3modal.com")
        let response = try await httpClient.request(
            GetWalletsResponse.self,
            at: Web3ModalAPI.getWallets(
                params: params
            )
        )
    
        try await fetchWalletImages(for: response.data)
        
        DispatchQueue.main.async { [self] in
            var wallets = response.data
                
            for index in wallets.indices {
                let contains = store.installedWalletIds.contains(wallets[index].id)
                wallets[index].isInstalled = contains
            }
            
            if !search.isEmpty {
                let matchingCustomWallets = store.customWallets.filter { wallet in
                    wallet.name.contains(search)
                }
                
                self.store.searchedWallets = wallets + matchingCustomWallets
            } else {
                self.store.searchedWallets = []
                self.store.wallets.formUnion(wallets + store.customWallets)
                self.totalEntries = response.count
                self.store.totalPages = Int(ceil(Double(response.count) / Double(entriesPerPage)))
            }
            
            self.isLoading = false
        }
    }
    
    func fetchAllWalletMetadata() async throws {
        let httpClient = HTTPNetworkClient(host: "api.web3modal.com")
        let response = try await httpClient.request(
            GetIosDataResponse.self,
            at: Web3ModalAPI.getIosData(
                params: .init(
                    projectId: AppKit.config.projectId,
                    metadata: AppKit.config.metadata
                )
            )
        )
    
        let installedWallets: [String?] = try await response.data.concurrentMap { walletMetadata in
            guard
                let nativeUrl = URL(string: walletMetadata.ios_schema),
                await UIApplication.shared.canOpenURL(nativeUrl)
            else {
                return nil
            }
                
            return walletMetadata.id
        }
            
        store.installedWalletIds = installedWallets.compactMap { $0 }
    }
    
    func fetchFeaturedWallets() async throws {
        let httpClient = HTTPNetworkClient(host: "api.web3modal.com")
        let response = try await httpClient.request(
            GetWalletsResponse.self,
            at: Web3ModalAPI.getWallets(
                params: .init(
                    page: 1,
                    entries: 4,
                    search: "",
                    projectId: AppKit.config.projectId,
                    metadata: AppKit.config.metadata,
                    recommendedIds: AppKit.config.recommendedWalletIds,
                    excludedIds: AppKit.config.excludedWalletIds
                )
            )
        )
        
        try await fetchWalletImages(for: response.data)
        
        DispatchQueue.main.async { [self] in
            
            var wallets = response.data
            
            for index in wallets.indices {
                let contains = store.installedWalletIds.contains(wallets[index].id)
                wallets[index].isInstalled = contains
            }
            
            self.store.totalNumberOfWallets = response.count
            self.store.featuredWallets.append(contentsOf: wallets)
        }
    }
    
    func fetchWalletImages(for wallets: [Wallet]) async throws {
        var walletImages: [String: UIImage] = [:]
        
        try await wallets.concurrentMap { wallet in
            
            // Build URL
            var imageUrl: URL?
            if let imageId = wallet.imageId {
                imageUrl = URL(string: "https://api.web3modal.com/getWalletImage/\(imageId)")
            } else if let customImageUrl = wallet.imageUrl {
                imageUrl = URL(string: customImageUrl)
            }
            
            // Check whether we have some url and not fetched already
            guard
                let imageUrl,
                !self.store.walletImages.contains(where: { key, _ in key == wallet.id })
            else {
                return ("", UIImage?.none)
            }
            
            var request = URLRequest(url: imageUrl)
            request.setW3MHeaders()
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let image = UIImage(data: data)
                return (wallet.id, image)
            } catch {
                print(error.localizedDescription)
            }
            
            return ("", UIImage?.none)
        }
        // Assign to outside dictionary
        .forEach { (key: String, value: UIImage?) in
            if value == nil || key == "" {
                return
            }
            
            walletImages[key] = value
        }
        
        // Update images in Store
        DispatchQueue.main.async { [walletImages] in
            self.store.walletImages.merge(walletImages) { _, new in
                new
            }
        }
    }
    
    func prefetchChainImages() async throws {
        var chainImages: [String: UIImage] = [:]
        
        try await ChainPresets.ethChains.concurrentMap { chain in
            do {
                let image = try await self.fetchAssetImage(id: chain.imageId)
                return (chain.imageId, image)
            } catch {
                print(error.localizedDescription)
            }
            
            return ("", UIImage?.none)
        }
        .forEach { key, value in
            if value == nil {
                return
            }
            
            chainImages[key] = value
        }
        
        DispatchQueue.main.async { [chainImages] in
            self.store.chainImages.merge(chainImages) { _, new in
                new
            }
        }
    }
    
    func fetchAssetImage(id: String) async throws -> UIImage? {
        
        let url = URL(string: "https://api.web3modal.com/public/getAssetImage/\(id)")!
        var request = URLRequest(url: url)
        request.setW3MHeaders()
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return UIImage(data: data)
    }
    
    func fetchWalletImage(id: String) async throws -> UIImage? {
        
        let url = URL(string: "https://api.web3modal.com/getWalletImage/\(id)")!
        var request = URLRequest(url: url)
        request.setW3MHeaders()
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return UIImage(data: data)
    }
}

extension URLRequest {
    mutating func setW3MHeaders() {
        setValue(AppKit.config.projectId, forHTTPHeaderField: "x-project-id")
        setValue(AppKit.Config.sdkType, forHTTPHeaderField: "x-sdk-type")
        setValue(AppKit.Config.sdkVersion, forHTTPHeaderField: "x-sdk-version")
        setValue(EnvironmentInfo.sdkVersion, forHTTPHeaderField: "User-Agent")
    }
}
