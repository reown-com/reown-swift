import SwiftUI


public struct Web3ModalNetworkButton: View {
    @ObservedObject var store: Store
        
    @Environment(\.analyticsService) var analyticsService
    
    public init() {
        self.store = .shared
    }
    
    init(store: Store = .shared) {
        self.store = store
    }
    
    public var body: some View {
        if let selectedChain = store.selectedChain {
            Button(selectedChain.chainName) {
                AppKit.selectChain()
            }
            .buttonStyle(
                W3MChipButtonStyle(
                    variant: .shade,
                    leadingImage: {
                        if let storedImage = store.chainImages[selectedChain.imageId] {
                            Circle()
                                .fill(.GrayGlass005)
                                .backport.overlay {
                                    Image(uiImage: storedImage)
                                        .resizable()
                                        .frame(width: 22, height: 22)
                                        .clipShape(Circle())
                                }
                                .frame(width: 26, height: 26)
                        } else {
                            networkImagePlaceholder()
                        }
                    }
                )
            )
        } else {
            Button {
                analyticsService.track(.CLICK_NETWORKS)
                AppKit.selectChain()
            } label: {
                Text("Select network").foregroundColor(.Foreground100)
            }
            .buttonStyle(
                W3MChipButtonStyle(
                    variant: .shade,
                    leadingImage: {
                        networkImagePlaceholder()
                    }
                )
            )
        }
    }
    
    private func networkImagePlaceholder() -> some View {
        Circle().fill(.GrayGlass010, strokeBorder: .GrayGlass005, lineWidth: 2)
            .backport.overlay {
                Image.Bold.network
                    .foregroundColor(.Foreground200)
                    .padding(Spacing.xs)
            }
            .frame(width: 24, height: 24)
    }
}

#if DEBUG

public struct NetworkButtonPreviewView: View {
    public init() {}
    
    static let store = { (chain: Chain?) -> Store in
        let store = Store()
        store.balance = 1.23
        store.selectedChain = chain
        store.chainImages[ChainPresets.ethChains[0].imageId] = UIImage(
            named: "MockWalletImage", in: .coreModule, compatibleWith: nil
        )
        
        return store
    }
    
    public var body: some View {
        VStack {
            Web3ModalNetworkButton(store: NetworkButtonPreviewView.store(nil))
            
            Web3ModalNetworkButton(store: NetworkButtonPreviewView.store(ChainPresets.ethChains[0]))
            
            Web3ModalNetworkButton(store: NetworkButtonPreviewView.store(ChainPresets.ethChains[1]))
            
            Web3ModalNetworkButton(store: NetworkButtonPreviewView.store(ChainPresets.ethChains[0]))
                .disabled(true)
            
            Web3ModalNetworkButton(store: NetworkButtonPreviewView.store(nil))
                .disabled(true)
        }
    }
}

struct NetworkButton_Preview: PreviewProvider {
    static var previews: some View {
        NetworkButtonPreviewView()
    }
}

#endif
