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
        HStack(spacing: 0) {
            switch router.currentRoute as? Router.ConnectingSubpage {
            case .none:
                EmptyView()
            case .connectWallet:
                helpButton()
            default:
                backButton()
            }
            
            Spacer()
            
            (router.currentRoute as? Router.ConnectingSubpage)?.title.map { title in
                Text(title)
                    .font(.paragraph700)
            }
            
            Spacer()
            
            closeButton()
        }
        .padding()
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .foregroundColor(.Foreground100)
        .overlay(
            RoundedCorner(radius: 30, corners: [.topLeft, .topRight])
                .stroke(Color.GrayGlass005, lineWidth: 1)
        )
        .cornerRadius(30, corners: [.topLeft, .topRight])
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
