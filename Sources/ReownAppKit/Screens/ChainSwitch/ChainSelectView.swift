import SwiftUI

struct ChainSelectView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var store: Store
    
    @ObservedObject var viewModel: Web3ModalViewModel

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
        switch router.currentRoute as? Router.NetworkSwitchSubpage {
        case .none:
            EmptyView()
        case .selectChain:
            if #available(iOS 14.0, *) {
                grid()
            } else {
                Text("Please upgrade to iOS 14 to use this feature")
            }
        case .whatIsANetwork:
            WhatIsNetworkView()
        case let .networkDetail(chain):
            NetworkDetailView(viewModel: .init(chain: chain, router: router))
        }
    }
    
    @available(iOS 14.0, *)
    @ViewBuilder
    private func grid() -> some View {
        let numberOfColumns = calculateNumberOfColumns()
        let columns = Array(repeating: GridItem(.flexible()), count: numberOfColumns)
        let maxNumberOfRows = ceil(Double(ChainPresets.ethChains.count) / Double(numberOfColumns))
        let numberOfRows = min(4, maxNumberOfRows)

        VStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.l) {
                    ForEach(ChainPresets.ethChains, id: \.self) { chain in
                        gridElement(for: chain)
                    }
                }
            }
            .frame(height: numberOfRows * 96 + (numberOfRows - 1) * Spacing.l)
            .padding(Spacing.s)
            
            Divider()
                .background(Color.GrayGlass005)
            
            VStack(spacing: 0) {
                Text("Your connected wallet may not support some of the networks available for this dApp")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.small400)
                    .foregroundColor(.Foreground300)
                    .multilineTextAlignment(.center)
                
                Button {
                    router.setRoute(Router.NetworkSwitchSubpage.whatIsANetwork)
                    analyticsService.track(.CLICK_NETWORK_HELP)
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image.Bold.questionMarkCircle
                            .resizable()
                            .frame(width: 12, height: 12)
                        
                        Text("What is a network")
                    }
                    .foregroundColor(.Blue100)
                    .font(.small600)
                }
                .padding(.vertical, Spacing.s)
                .background(Color.clear)
                .contentShape(Rectangle())
            }
            .padding(.horizontal)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xl)
        }
    }

    private func gridElement(for chain: Chain) -> some View {
        let isSelected = chain.id == store.selectedChain?.id
        let currentChains = viewModel.getChains()
        let currentMethods = viewModel.getMethods()
        let needToSendSwitchRequest = currentMethods.contains("wallet_switchEthereumChain")
        let isChainApproved = store.account != nil ? currentChains.contains(chain) : true
        
        return Button(action: {
            analyticsService.track(.SWITCH_NETWORK(network: chain))
            if store.account == nil {
                store.selectedChain = chain
                router.setRoute(Router.ConnectingSubpage.connectWallet)
            } else if isChainApproved, !needToSendSwitchRequest {
                store.selectedChain = chain
                router.setRoute(Router.AccountSubpage.profile)
            } else {
                router.setRoute(Router.NetworkSwitchSubpage.networkDetail(chain))
            }
        }, label: {
            Text(chain.chainName)
        })
        .buttonStyle(W3MCardSelectStyle(
            variant: .network,
            imageContent: {
                Image(
                    uiImage: store.chainImages[chain.imageId] ?? UIImage()
                )
                .resizable()
            },
            isSelected: isSelected
        ))
        .disabled({
            if isSelected {
                return true
            }
            
            if store.session == nil {
                return false
            }
            
            if needToSendSwitchRequest {
                return false
            }
            
            if !currentChains.contains(chain) {
                return true
            }
            
            return false
        }())
    }
    
    private func modalHeader() -> some View {
        HStack(spacing: 0) {
            switch router.currentRoute as? Router.NetworkSwitchSubpage {
            case .none:
                EmptyView()
            case .selectChain:
                if router.previousRoute as? Router.AccountSubpage == .profile {
                    backButton()
                }
            default:
                backButton()
            }
            
            Spacer()
            
            (router.currentRoute as? Router.NetworkSwitchSubpage)?.title.map { title in
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

extension Router.NetworkSwitchSubpage {
    var title: String? {
        switch self {
        case .selectChain:
            return "Select network"
        case .whatIsANetwork:
            return "What is a network?"
        case let .networkDetail(chain):
            return chain.chainName
        }
    }
}
