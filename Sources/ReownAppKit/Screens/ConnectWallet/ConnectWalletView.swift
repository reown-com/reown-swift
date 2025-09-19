import SwiftUI

struct ConnectWalletView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    @Environment(\.analyticsService) var analyticsService: AnalyticsService
    
    @EnvironmentObject var signInteractor: SignInteractor
    @State var loadingWalletId: String?
    @State var loadingWalletTask: Task<Void, Error>?

    let displayWCConnection = false
    
    var wallets: [Wallet] { Array(store.sortedWallets.prefix(7)) }
    
    init() {
        if let wallet = Store.shared.currentWallet {
            Store.shared.currentWallet = nil
            loadWallet(wallet)
        }
    }
    
    var body: some View {
        VStack {
            wcConnection()
            
            featuredWallets()
                
            Button(action: {
                router.setRoute(Router.ConnectingSubpage.allWallets)
                analyticsService.track(.CLICK_ALL_WALLETS)
            }, label: {
                Text("All wallets")
            })
            .buttonStyle(W3MListSelectStyle(
                imageContent: { _ in
                    Image.optionAll
                },
                tag: store.totalNumberOfWallets != 0 ? W3MTag(title: "\(store.totalNumberOfWallets)+", variant: .info) : nil
            ))
        }
        .padding(Spacing.s)
        .padding(.bottom)
    }
    
    private func loadWallet(_ wallet: Wallet) {
        let isLoading = loadingWalletId == wallet.id
        if isLoading { return }
        loadingWalletId = wallet.id
        loadingWalletTask?.cancel()
        
        loadingWalletTask = Task {
            do {
                defer {
                    loadingWalletId = nil
                    Store.shared.currentWallet = nil
                }
                
                if wallet.customDidSelect {
                    // Trigger this manually for custom wallets that don't use WC
                    AppKit.showConnectingWallet(wallet)
                }
                
                try await AppKit.instance.onWalletTap?(wallet)
            } catch {
                // Swallow the error, forget the toast
//                store.toast = .init(style: .error, message: error.localizedDescription)
            }
        }
    }
    
    @ViewBuilder
    private func featuredWallets() -> some View {
        ForEach(wallets, id: \.self) { wallet in
            Group {
                let isLoading = loadingWalletId == wallet.id
                let isRecent: Bool = wallet.isRecent
                let isInstalled: Bool = wallet.isInstalled
                let tagTitle: String? = isRecent ? "RECENT" : isInstalled ? "INSTALLED" : nil
                
                Button(action: {
                    analyticsService.track(.SELECT_WALLET(name: wallet.name, platform: .mobile))
                    loadWallet(wallet)
                }, label: {
                    Text(wallet.name)
                })
                .buttonStyle(W3MListSelectStyle(
                    imageContent: { _ in
                        Group {
                            CacheAsyncImage(url: wallet.appIconUrl, content: { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            }, placeholder: {
                                Image.Regular.wallet.resizable()
                                    .padding(Spacing.xxs)
                            })
                        }
                        .background(Color.Overgray005)
                        .backport.overlay {
                            RoundedRectangle(cornerRadius: Radius.xxxs)
                                .stroke(.Overgray010, lineWidth: 1)
                        }
                    },
                    tag: tagTitle != nil ? .init(title: tagTitle!, variant: .info) : nil,
                    isLoading: isLoading,
                ))
            }
        }
    }
    
    @ViewBuilder
    private func wcConnection() -> some View {
        if displayWCConnection {
            Button(action: {
                router.setRoute(Router.ConnectingSubpage.qr)
            }, label: {
                Text("WalletConnect")
            })
            .buttonStyle(W3MListSelectStyle(
                imageContent: { _ in
                    ZStack {
                        Color.Blue100
                        
                        Image.imageLogo
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.white)
                    }
                },
                tag: W3MTag(title: "QR CODE", variant: .main)
            ))
        }
    }
}

struct ConnectWalletView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectWalletView()
    }
}


struct CacheAsyncImage<Content, Placeholder>: View where Content: View, Placeholder: View {
    private let url: URL?
    private let scale: CGFloat
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    init(
        url: URL?,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        if let url, let cached = ImageCache[url] {
            content(cached)
        } else {
            AsyncImage(url: url, scale: scale) { phase in
                cacheAndRender(phase: phase)
            }
        }
    }

    private func cacheAndRender(phase: AsyncImagePhase) -> some View {
        switch phase {
        case .success(let image):
            if let url {
                ImageCache[url] = image
            }
            return AnyView(content(image))
        case .empty, .failure:
            return AnyView(placeholder())
        @unknown default:
            return AnyView(placeholder())
        }
    }
}

public final class ImageCache {
    static private var cache: [URL: Image] = [:]

    public static subscript(url: URL) -> Image? {
        get { cache[url] }
        set { cache[url] = newValue }
    }
}
