import UIKit
import Combine

final class W3MAPIInteractor: ObservableObject {
    @Published var isLoading: Bool = false
    
    private let store: Store
    private let uiApplicationWrapper: UIApplicationWrapper
    
    private let entriesPerPage: Int = 40
    private var cancellables = Set<AnyCancellable>()
    
    var totalEntries: Int = 0
    
        
    init(
        store: Store = .shared,
        uiApplicationWrapper: UIApplicationWrapper = .live
    ) {
        self.store = store
        self.uiApplicationWrapper = uiApplicationWrapper
        
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    try? await self?.detectInstalledWallets()
                }
            }
            .store(in: &cancellables)
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
            include: AppKit.config.includedWalletIds,
            exclude: AppKit.config.excludedWalletIds
        )

        let httpClient = HTTPNetworkClient(host: "api.web3modal.com")
        let response = try await httpClient.request(
            GetWalletsResponse.self,
            at: Web3ModalAPI.getWallets(
                params: params
            )
        )
            
        DispatchQueue.main.async { [self] in
            var wallets = response.data
                
            for index in wallets.indices {
                let contains = store.installedWalletIds.contains(wallets[index].id)
                wallets[index].isInstalled = contains
            }
            
            // Sort wallets based on recommendedWalletIds if they are set
            if !AppKit.config.recommendedWalletIds.isEmpty {
                wallets.sort { wallet1, wallet2 in
                    let index1 = AppKit.config.recommendedWalletIds.firstIndex(of: wallet1.id)
                    let index2 = AppKit.config.recommendedWalletIds.firstIndex(of: wallet2.id)
                    
                    // Both wallets are in the recommendedWalletIds array
                    if let index1 = index1, let index2 = index2 {
                        return index1 < index2 // Maintain the order they were specified in the array
                    }
                    // Only wallet1 is in the recommendedWalletIds array
                    else if index1 != nil {
                        return true
                    }
                    // Only wallet2 is in the recommendedWalletIds array
                    else if index2 != nil {
                        return false
                    }
                    // Neither wallet is in the recommendedWalletIds array
                    else {
                        return wallet1.order < wallet2.order
                    }
                }
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
    
        // Determine if there are new schemes that should be added to app's LSApplicationQueriesSchemes
        let registeredSchemes = response.data.map { $0.ios_schema.components(separatedBy: ":")[0].lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        let bundleSchemes = AppKit.config.queryableWalletSchemes
        let newSchemes = registeredSchemes.filter { !bundleSchemes.contains($0) }
        if newSchemes.count > 0 {
            print("[AppKit] \(newSchemes.count) of \(registeredSchemes.count) (current: \(bundleSchemes.count)) schemes should be added to the app's Info.plist:\n\(newSchemes)\n")
        }

        // Detect which wallets are installed
        let data: [WalletMetadata] = response.data.map { .init(id: $0.id, scheme: $0.ios_schema) }
        store.walletMetdata = data
        try await detectInstalledWallets()
    }
    
    @MainActor
    func detectInstalledWallets() async throws {
        do {
            // Make copy to avoid race in concurrentMap
            var data = store.walletMetdata
            
            // Custom wallets
            for (index, customWallet) in store.customWallets.enumerated() {
                let metadata = WalletMetadata(id: customWallet.id, scheme: customWallet.mobileLink ?? "")
                store.customWallets[index].isInstalled = metadata.isInstalled()
                data.append(metadata)
            }
            
            let installedWallets: [String?] = try await data.concurrentMap { walletMetadata in
                guard walletMetadata.isInstalled() else { return nil }
                return walletMetadata.id
            }
            store.installedWalletIds = installedWallets.compactMap { $0 }
        } catch {
            print("Error detecting installed wallets: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchFeaturedWallets() async throws {
        let walletsToFetch = AppKit.config.recommendedWalletIds + store.installedWalletIds
        let httpClient = HTTPNetworkClient(host: "api.web3modal.com")
        let include = AppKit.config.includedWalletIds + AppKit.config.recommendedWalletIds
        
        let response = try await httpClient.request(
            GetWalletsResponse.self,
            at: Web3ModalAPI.getWallets(
                params: .init(
                    page: 1,
                    entries: max(walletsToFetch.count, 6),
                    search: "",
                    projectId: AppKit.config.projectId,
                    metadata: AppKit.config.metadata,
                    include: walletsToFetch,
                    exclude: AppKit.config.excludedWalletIds
                )
            )
        )
                
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
    
    // Use this to populate the totalNumberOfWallets. The fetch with 'include' only returns the # returned instead of total
    func fetchAllWalletsFirstPage() async throws {
        let walletsToFetch = AppKit.config.recommendedWalletIds + store.installedWalletIds
        let httpClient = HTTPNetworkClient(host: "api.web3modal.com")
        let response = try await httpClient.request(
            GetWalletsResponse.self,
            at: Web3ModalAPI.getWallets(
                params: .init(
                    page: 1,
                    entries: entriesPerPage,
                    search: "",
                    projectId: AppKit.config.projectId,
                    metadata: AppKit.config.metadata,
                    include: AppKit.config.includedWalletIds,
                    exclude: AppKit.config.excludedWalletIds
                )
            )
        )
                
        DispatchQueue.main.async { [self] in
            
            var wallets = response.data
            
            for index in wallets.indices {
                let contains = store.installedWalletIds.contains(wallets[index].id)
                wallets[index].isInstalled = contains
            }
            
            // Sort featured wallets based on recommendedWalletIds if they are set
            if !AppKit.config.recommendedWalletIds.isEmpty {
                wallets.sort { wallet1, wallet2 in
                    let index1 = AppKit.config.recommendedWalletIds.firstIndex(of: wallet1.id)
                    let index2 = AppKit.config.recommendedWalletIds.firstIndex(of: wallet2.id)
                    
                    // Both wallets are in the recommendedWalletIds array
                    if let index1 = index1, let index2 = index2 {
                        return index1 < index2 // Maintain the order they were specified in the array
                    }
                    // Only wallet1 is in the recommendedWalletIds array
                    else if index1 != nil {
                        return true
                    }
                    // Only wallet2 is in the recommendedWalletIds array
                    else if index2 != nil {
                        return false
                    }
                    // Neither wallet is in the recommendedWalletIds array
                    else {
                        return wallet1.order < wallet2.order
                    }
                }
            }
            
            self.store.totalNumberOfWallets = response.count
            self.store.featuredWallets.append(contentsOf: wallets)
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
        setValue(EnvironmentInfo.sdkName, forHTTPHeaderField: "User-Agent")
    }
}
