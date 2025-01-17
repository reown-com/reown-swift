import SwiftUI


struct AccountView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var blockchainApiInteractor: BlockchainAPIInteractor
    @EnvironmentObject var signInteractor: SignInteractor
    @EnvironmentObject var store: Store
    
    var addressFormatted: String? {
        guard let address = store.account?.address else {
            return nil
        }
        
        return String(address.prefix(4)) + "..." + String(address.suffix(4))
    }
    
    var selectedChain: Chain {
        return store.selectedChain ?? ChainPresets.ethChains.first!
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                avatar()
                
                Spacer()
                    .frame(height: Spacing.xl)
                
                HStack {
                    (store.identity?.name ?? addressFormatted).map {
                        Text($0)
                            .font(.title600)
                            .foregroundColor(.Foreground100)
                    }
                    
                    Button {
                        UIPasteboard.general.string = store.session?.accounts.first?.address
                        store.toast = .init(style: .success, message: "Address copied")
                    } label: {
                        Image.Medium.copy
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.Foreground250)
                    }
                }
                
                Spacer()
                    .frame(height: Spacing.xxxxs)
                
                if store.balance != nil {
                    let balance = store.balance?.roundedDecimal(to: 4, mode: .down) ?? 0
                    
                    Text(balance == 0 ? "0 \(selectedChain.token.symbol)" : "\(balance, specifier: "%.4f") \(selectedChain.token.symbol)")
                        .font(.paragraph500)
                        .foregroundColor(.Foreground200)
                }
                
                Spacer()
                    .frame(height: Spacing.s)
                
                Button {
                    guard let chain = store.selectedChain else { return }
                    
                    router.openURL(URL(string: chain.blockExplorerUrl)!)
                } label: {
                    Text("Block Explorer")
                }
                .buttonStyle(W3MChipButtonStyle(
                    variant: .transparent,
                    size: .s,
                    leadingImage: {
                        Image.Medium.compass
                            .resizable()
                    },
                    trailingImage: {
                        Image.Bold.externalLink
                            .resizable()
                    }
                ))
                
            }
            
            Spacer()
                .frame(height: Spacing.xl)

            Button {
                router.setRoute(Router.NetworkSwitchSubpage.selectChain)
            } label: {
                Text(selectedChain.chainName)
            }
            .buttonStyle(W3MListSelectStyle(imageContent: { _ in
                Image(
                    uiImage: store.chainImages[selectedChain.imageId] ?? UIImage()
                )
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            }))
            
            Spacer()
                .frame(height: Spacing.xs)
            
            Button {
                disconnect()
            } label: {
                Text("Disconnect")
            }
            .buttonStyle(W3MListSelectStyle(imageContent: { _ in
                Image.Medium.disconnect
                    .resizable()
                    .frame(width: 14, height: 14)
                    .padding(Spacing.xxxs)
                    .frame(width: 32, height: 32)
                    .background(Color.GrayGlass010)
                    .clipShape(Circle())
            }))
            
            Spacer()
                .frame(height: Spacing.m)
        }
        .padding(.horizontal, Spacing.s)
        .padding(.top, 40)
        .padding(.bottom)
        .onAppear {
            Task {
                do {
                    try await blockchainApiInteractor.getBalance()
                } catch {
//                    store.toast = .init(style: .error, message: "Network error")
                    AppKit.config.onError(error)
                }
            }
            
            guard store.identity == nil else {
                return
            }
            
            Task {
                do {
                    try await blockchainApiInteractor.getIdentity()
                } catch {
//                    store.toast = .init(style: .error, message: "Network error")
                    AppKit.config.onError(error)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.Background125)
        .overlay(closeButton().padding().foregroundColor(.Foreground100), alignment: .topTrailing)
        .cornerRadius(30, corners: [.topLeft, .topRight])
    }
    
    @ViewBuilder
    func avatar() -> some View {
        if let avatarUrlString = store.identity?.avatar, let url = URL(string: avatarUrlString) {
            Backport.AsyncImage(url: url)
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().stroke(.GrayGlass010, lineWidth: 8))
        } else if let address = store.account?.address {
            W3MAvatarGradient(address: address)
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(.GrayGlass010, lineWidth: 8))
        }
    }
    
    func disconnect() {
        Task {
            do {
                router.setRoute(Router.ConnectingSubpage.connectWallet)
                try await signInteractor.disconnect()
            } catch {
//                store.toast = .init(style: .error, message: "Network error")
            }
        }
    }
    
    private func closeButton() -> some View {
        Button {
            withAnimation {
                store.isModalShown = false
            }
        } label: {
            Image.Medium.xMark
        }
    }
}

extension Double {
    func roundedDecimal(to scale: Int = 0, mode: NSDecimalNumber.RoundingMode = .plain) -> Double {
        var decimalValue = Decimal(self)
        var result = Decimal()
        NSDecimalRound(&result, &decimalValue, scale, mode)
        return Double(truncating: result as NSNumber)
    }
}

