import Combine
import SwiftUI
import UIKit


@available(iOS 14.0, *)
struct AllWalletsView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var store: Store
    @EnvironmentObject var interactor: W3MAPIInteractor

    @Environment(\.analyticsService) var analyticsService: AnalyticsService
    
    @EnvironmentObject var signInteractor: SignInteractor

    @State var searchTerm: String = ""
    @State private var hasSearched: Bool = false
    let searchTermPublisher = PassthroughSubject<String, Never>()
    
    @State var loadingWalletId: String?
    @State var loadingWalletTask: Task<Void, Error>?
    
    private let semaphore = AsyncSemaphore(count: 1)
    
    var isSearching: Bool {
        searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
    
    var body: some View {
        content()
    }
    
    @ViewBuilder
    private func content() -> some View {
        VStack(spacing: 0) {
            HStack {
                W3MTextField("Search wallet", text: $searchTerm)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    
                qrButton()
            }
            .padding(.horizontal)
            .padding(.vertical, Spacing.xs)
            
            if isSearching {
                searchGrid()
            } else {
                regularGrid()
            }
        }
        .onAppear {
            fetchWallets()
        }
        .animation(.default, value: isSearching)
        .frame(maxHeight: UIScreen.main.bounds.height - 240)
        .backport.onChange(of: searchTerm) { searchTerm in
            searchTermPublisher.send(searchTerm)
        }
        .onReceive(
            searchTermPublisher
                .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
                .filter { string in
                    string.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
                }
                .removeDuplicates()
        ) { debouncedSearchTerm in
            let trimmedSearchTerm = debouncedSearchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            fetchWallets(search: trimmedSearchTerm)
        }
        .onReceive(
            searchTermPublisher
                .receive(on: DispatchQueue.main)
                .removeDuplicates()
        ) { searchTerm in
            if searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                store.searchedWallets = []
            }
        }
    }
    
    @ViewBuilder
    private func regularGrid() -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible()),
                    count: calculateNumberOfColumns()
                ),
                spacing: Spacing.l
            ) {
                ForEach(store.sortedWallets, id: \.self) { wallet in
                    gridElement(for: wallet)
                }
                
                if interactor.isLoading || store.currentPage < store.totalPages {
                    ForEach(1 ... calculateNumberOfColumns() * 4, id: \.self) { _ in
                        Button(action: {}, label: { Text("Loading") })
                            .buttonStyle(W3MCardSelectStyle(
                                variant: .wallet,
                                imageContent: {
                                    Color.Overgray005.modifier(ShimmerBackground())
                                },
                                isLoading: .constant(true)
                            ))
                    }
                    .onAppear {
                        fetchWallets()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 60)
        }
    }
    
    @ViewBuilder
    private func searchGrid() -> some View {
        Group {
            ZStack(alignment: .top) {
                Spacer().frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                ProgressView()
                    .opacity(interactor.isLoading ? 1 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if hasSearched && !interactor.isLoading && store.searchedWallets.isEmpty {
                    VStack {
                        Spacer().frame(height: 80)
                        Text("No results found")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                    
                let columns = Array(
                    repeating: GridItem(.flexible()),
                    count: calculateNumberOfColumns()
                )
                    
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Spacing.l) {
                        ForEach(store.sortedSearchWallets, id: \.self) { wallet in
                            gridElement(for: wallet)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .opacity(store.searchedWallets.isEmpty ? 0 : 1)
            }
        }
        .animation(.default, value: interactor.isLoading)
        .animation(.default, value: store.searchedWallets.isEmpty)
    }
    
    private func gridElement(for wallet: Wallet) -> some View {
        Button(action: {
            analyticsService.track(.SELECT_WALLET(name: wallet.name, platform: .mobile))
            loadWallet(wallet)
        }, label: {
            Text(wallet.name)
        })
        .buttonStyle(W3MCardSelectStyle(
            variant: .wallet,
            imageContent: {
                CacheAsyncImage(url: wallet.appIconUrl, content: { image in
                    image
                        .resizable()
                        .scaledToFit()
                }, placeholder: {
                    Image.Regular.wallet.resizable()
                })
            },
            isLoading: .init(
                get: { loadingWalletId == wallet.id },
                set: { _ in }
            )
        ))
        .id(wallet.id)
    }
    
    private func loadWallet(_ wallet: Wallet) {
        let isLoading = loadingWalletId == wallet.id
        if isLoading { return }
        loadingWalletId = wallet.id
        loadingWalletTask?.cancel()
        
        loadingWalletTask = Task {
            defer {
                loadingWalletId = nil
                Store.shared.currentWallet = nil
            }
            
            AppKit.showConnectingWallet(wallet)
            await AppKit.instance.onWalletTap?(wallet)
        }
    }
    
    private func fetchWallets(search: String = "") {
        Task {
            do {
                try await semaphore.withTurn {
                    try await interactor.fetchWallets(search: search)
                }
                if !search.isEmpty {
                    DispatchQueue.main.async {
                        self.hasSearched = true
                    }
                }
            } catch {
                store.toast = .init(style: .error, message: "Network error")
            }
        }
    }
    
    private func qrButton() -> some View {
        Button {
            router.setRoute(Router.ConnectingSubpage.qr)
            analyticsService.track(.SELECT_WALLET(name: "Unknown", platform: .qrcode))
        } label: {
            Image.optionQrCode
        }
    }
    
    private func calculateNumberOfColumns() -> Int {
        let itemWidth: CGFloat = 76
        
        let screenWidth = UIScreen.main.bounds.width
        let count = floor(screenWidth / itemWidth)
        let spaceLeft = screenWidth.truncatingRemainder(dividingBy: itemWidth)
        let spacing = spaceLeft / (count - 1)
        let updatedCount = spacing < 4 ? count - 1 : count
        
        return Int(updatedCount)
    }
}
