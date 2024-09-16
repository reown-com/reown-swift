import SwiftUI

struct WalletDetailView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @EnvironmentObject var store: Store
    
    @ObservedObject var viewModel: WalletDetailViewModel
    
    var body: some View {
        content()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.handle(.onAppear)
                }
            }
    }
    
    @ViewBuilder
    func content() -> some View {
        VStack(spacing: 0) {
            if viewModel.showToggle {
                picker()
            }
            
            walletInfo()
            
            if viewModel.wallet.isInstalled == true && !store.SIWEFallbackState {
                copyLink()
            }

            if 
                viewModel.preferredPlatform == .mobile,
                viewModel.wallet.isInstalled != true,
                viewModel.wallet.appStore != nil
            {
                appStoreRow()
            }

            if store.SIWEFallbackState {
                siweFallbackButtons()
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.bottom, Spacing.xl + 17)
    }

    private func siweFallbackButtons() -> some View {
        HStack {
            Button(action: {
                Task {
                    try await viewModel.cancel()
                }
            }) {
                Text("Cancel")
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }

            Button(action: {
                Task {
                    try await viewModel.signSIWE()
                }
            }) {
                Text("Sign")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func picker() -> some View {
        W3MPicker(
            WalletDetailViewModel.Platform.allCases,
            selection: viewModel.preferredPlatform
        ) { item in
            
            HStack {
                switch item {
                case .mobile:
                    Image.Bold.mobile
                case .browser:
                    Image.Bold.browser
                }
                
                Text(item.rawValue.capitalized)
            }
            .font(.small500)
            .multilineTextAlignment(.center)
            .foregroundColor(viewModel.preferredPlatform == item ? .Foreground100 : .Foreground200)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.preferredPlatform = item
                }
            }
        }
        .frame(maxWidth: 200)
        .padding(.top, Spacing.l)
    }
    
    private func copyLink() -> some View {
        Button {
            viewModel.handle(.didTapCopy)
        } label: {
            HStack(spacing: Spacing.xxxs) {
                Image.Bold.copy
                    .resizable()
                    .frame(width: 12, height: 12)
                Text("Copy link")
            }
            .font(.small600)
            .foregroundColor(.Foreground200)
            .padding(Spacing.xs)
        }
        .padding(.bottom, Spacing.xl)
    }
    
    private func walletImage() -> some View {
        return ZStack {
            Image(
                uiImage: store.walletImages[viewModel.wallet.id] ?? UIImage()
            )
            .resizable()
            .frame(width: 80, height: 80)
            .cornerRadius(Radius.m)
            .backport.overlay(alignment: .bottomTrailing) {
                Image.Bold.xMark
                    .resizable()
                    .foregroundColor(.Error100)
                    .frame(width: 10, height: 10)
                    .padding(5)
                    .background(Color.Error100.opacity(0.15))
                    .clipShape(Circle())
                    .padding(2)
                    .background(Color.Background125)
                    .clipShape(Circle())
                    .opacity(store.retryShown ? 1 : 0)
                    .offset(x: 5, y: 5)
            }
            
            if !store.retryShown {
                DrawingProgressView(
                    shape: .roundedRectangleRelative(relativeCornerRadius: Radius.m / 80),
                    color: .Blue100,
                    lineWidth: 3,
                    isAnimating: .constant(true)
                )
                .frame(width: 90, height: 90)
            }
        }
    }
    
    private func retryButton() -> some View {
        return Button {
            viewModel.handle(.didTapOpen)
        } label: {
            HStack {
                Text(!store.retryShown ? "Open" : "Try again")
            }
            .font(.small600)
            .foregroundColor(.Blue100)
        }
        .buttonStyle(
            W3MButtonStyle(
                size: .m,
                variant: .accent,
                leftIcon: store.retryShown ? Image.Bold.refresh : nil,
                rightIcon: store.retryShown ? nil : Image.Bold.externalLink
            )
        )
    }
    
    private func walletInfo() -> some View {
        VStack(spacing: 0) {
            walletImage()
                .padding(.top, 40)
                .padding(.bottom, Spacing.xl)

            Text(store.SIWEFallbackState ? "Web3Modal needs to connect to your wallet." : (store.retryShown ? "Connection declined" : "Continue in \(viewModel.wallet.name)"))
                .font(.paragraph600)
                .foregroundColor(store.retryShown ? .Error100 : .Foreground100)
                .padding(.bottom, Spacing.xs)

            Text(
                store.SIWEFallbackState
                    ? "Sign this message to prove you own this wallet and proceed. Cancelling will disconnect you."
                    : (store.retryShown
                        ? "Connection can be declined if a previous request is still active"
                        : viewModel.preferredPlatform == .browser ? "Open and continue in a new browser tab" : "Accept connection request in the wallet")
            )
            .font(.small500)
            .foregroundColor(.Foreground200)
            .multilineTextAlignment(.center)
            .padding(.bottom, Spacing.l)

            if store.retryShown || viewModel.preferredPlatform == .browser {
                retryButton()
            }
        }
    }

    func appStoreRow() -> some View {
        HStack(spacing: 0) {
            Text("Don't have \(viewModel.wallet.name)?")
                .font(.paragraph500)
                .foregroundColor(.Foreground200)
            
            Spacer()
            
            Button {
                viewModel.handle(.didTapAppStore)
            } label: {
                Text("Get")
            }
            .buttonStyle(GetWalletButtonStyle())
        }
        .padding()
        .frame(height: 56)
        .background(Color.GrayGlass002)
        .cornerRadius(Radius.xs)
    }
    
    struct GetWalletButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: Spacing.xxxs) {
                configuration.label
                Image.Bold.chevronRight
                    .resizable()
                    .frame(width: 12, height: 12)
            }
            .font(.small600)
            .foregroundColor(.Blue100)
            .padding([.vertical, .trailing], Spacing.xs)
            .padding(.leading, Spacing.s)
            .background(configuration.isPressed ? Color.GrayGlass010 : Color.clear)
            .backport.overlay {
                Capsule()
                    .stroke(.GrayGlass010, lineWidth: 1)
            }
            .clipShape(Capsule())
        }
    }
}

#if DEBUG

class MockSignInteractor: SignInteractor {
    override func connect(walletUniversalLink: String?) async throws {
        // no-op
    }
    
    override func disconnect() async throws {
        // no-op
    }
}

class MockWalletDetailViewModel: WalletDetailViewModel {
    convenience init(retryShown: Bool, isInstalled: Bool, store: Store) {
        var wallet = Wallet.stubList.first!
        wallet.isInstalled = isInstalled
        
        self.init(
            wallet: wallet,
            router: Router(),
            signInteractor: MockSignInteractor(store: store),
            store: store
        )
        
//        self.retryShown = retryShown
    }
    
    override func startObserving() {
        // no-op
    }
    
    override func handle(_ event: Event) {
        // no-op
    }
}

struct WalletDetailView_Preview: PreviewProvider {
    static let store = {
        let store = Store()
        store.walletImages["0528ee7e-16d1-4089-21e3-bbfb41933100"] = UIImage(
            named: "MockWalletImage", in: .coreModule, compatibleWith: nil
        )
        
        return store
    }()
    
    static var previews: some View {
        ScrollView {
            WalletDetailView(
                viewModel: MockWalletDetailViewModel(
                    retryShown: false,
                    isInstalled: false,
                    store: WalletDetailView_Preview.store
                )
            )
            
            Divider()
            
            WalletDetailView(
                viewModel: MockWalletDetailViewModel(
                    retryShown: true,
                    isInstalled: false,
                    store: WalletDetailView_Preview.store
                )
            )
            
            Divider()
            
            WalletDetailView(
                viewModel: MockWalletDetailViewModel(
                    retryShown: true,
                    isInstalled: true,
                    store: WalletDetailView_Preview.store
                )
            )
            
            Divider()
            
            WalletDetailView(
                viewModel: MockWalletDetailViewModel(
                    retryShown: false,
                    isInstalled: true,
                    store: WalletDetailView_Preview.store
                )
            )
            
            Divider()
        }
        .environmentObject(WalletDetailView_Preview.store)
    }
}

#endif
