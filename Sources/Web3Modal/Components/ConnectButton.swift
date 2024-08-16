import SwiftUI


public struct ConnectButton: View {
    @ObservedObject var store: Store
    
    public init() {
        self.store = .shared
    }
    
    init(store: Store = .shared) {
        self.store = store
    }
    
    public var body: some View {
        Button {
            Web3Modal.present()
        } label: {
            if store.connecting {
                HStack {
                    DrawingProgressView(
                        shape: .circle,
                        color: .white,
                        lineWidth: 2,
                        duration: 1,
                        isAnimating: .constant(true)
                    )
                    .frame(width: 20, height: 20)
                    
                    Text("Connecting...")
                }
            } else {
                Text("Connect wallet")
            }
        }
        .buttonStyle(W3MChipButtonStyle())
    }
}

struct ConnectButton_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            ConnectButton()
            
            ConnectButton()
                .disabled(true)
        }
    }
}
