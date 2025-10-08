import SwiftUI

struct Web3ModalView: View {
    @ObservedObject var viewModel: Web3ModalViewModel

    @EnvironmentObject var signInteractor: SignInteractor
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    @Environment(\.analyticsService) var analyticsService: AnalyticsService

    var body: some View {
        VStack(spacing: 0) {
            modalHeader()
            routes()
        }
        .background(Color.Background125)
        .cornerRadius(30, corners: [.topLeft, .topRight])
    }
    
    @ViewBuilder
    private func routes() -> some View {
        switch router.currentRoute as? Router.ConnectingSubpage {
        case .none:
            EmptyView()
        case .connectWallet:
            ConnectWalletView()
        case .allWallets:
            if #available(iOS 14.0, *) {
                AllWalletsView()
            } else {
                Text("Please upgrade to iOS 14 to use this feature")
            }
        case .qr:
            ConnectWithQRCode()
        case .whatIsAWallet:
            WhatIsWalletView()
        case let .walletDetail(wallet):
            WalletDetailView(
                viewModel: .init(
                    wallet: wallet,
                    router: router,
                    signInteractor: signInteractor,
                    store: store
                )
            )
        case .getWallet:
            GetAWalletView()
        }
    }
    
    private func modalHeader() -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                switch router.currentRoute as? Router.ConnectingSubpage {
                case .none:
                    EmptyView()
                case .connectWallet:
                    //                helpButton()
                    EmptyView()
                default:
                    backButton()
                }
                
                Spacer()
                
                (router.currentRoute as? Router.ConnectingSubpage)?.title.map { title in
                    Text(title)
                        .font(.title700)
                        .foregroundColor(.Foreground100)
                }
                
                Spacer()
                
                closeButton()
            }
            
            if let connectingAddress {
                Text(connectingAddress)
                    .font(.paragraph700)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, connectingAddress != nil ? 4 : 24)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedCorner(radius: 30, corners: [.topLeft, .topRight])
                .stroke(Color.GrayGlass005, lineWidth: 1)
        )
        .cornerRadius(30, corners: [.topLeft, .topRight])
    }
    
    private var connectingAddress: String? {
        guard let account = store.connectingAccount else { return nil }
        return format(account.address)
    }
    
    public static let ellipsis = "····"
    private func format(_ value: String) -> String {
        // Greater than 12 since 10 or 11 would be shorter than the ellipsis
        guard value.count > 12 else { return value }
        
        // Use the first 6 charactors and the last 4 charactors of the hex address, and replace the rest with "..."
        let prefix = value.starts(with: "0x") ? value.prefix(6) : value.prefix(4)
        let suffix = value.suffix(4)
        return [prefix, suffix].joined(separator: Self.ellipsis)
    }
    
    private func helpButton() -> some View {
        Button(action: {
            router.setRoute(Router.ConnectingSubpage.whatIsAWallet)
            analyticsService.track(.CLICK_WALLET_HELP)
        }, label: {
            Image.Medium.questionMarkCircle
        })
    }
    
    private func backButton() -> some View {
        Button {
            router.goBack()
        } label: {
            Image.Medium.chevronLeft
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

extension Router.ConnectingSubpage {
    var title: String? {
        switch self {
        case .connectWallet:
            return "Connect wallet"
        case .qr:
            return "WalletConnect"
        case .allWallets:
            return "All wallets"
        case .whatIsAWallet:
            return "What is a wallet?"
        case let .walletDetail(wallet):
            return "\(wallet.name)"
        case .getWallet:
            return "Get wallet"
        }
    }
}

struct Web3ModalView_Previews: PreviewProvider {
    static var previews: some View {
        Web3ModalView(
            viewModel: .init(
                router: Router(),
                store: Store(),
                w3mApiInteractor: W3MAPIInteractor(store: Store()),
                signInteractor: SignInteractor(store: Store()),
                blockchainApiInteractor: BlockchainAPIInteractor(store: Store()), supportsAuthenticatedSession: false
            ))
            .previewLayout(.sizeThatFits)
    }
}
