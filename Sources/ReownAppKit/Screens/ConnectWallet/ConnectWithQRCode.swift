import SwiftUI


struct ConnectWithQRCode: View {
    
    @EnvironmentObject var store: Store
    @EnvironmentObject var signInteractor: SignInteractor
        
    var body: some View {
    
        VStack(spacing: Spacing.xl) {
            if let uri = store.uri?.absoluteString {
                
                QRCodeView(uri: uri)
            } else {
                RoundedRectangle(cornerRadius: Radius.l)
                    .fill(.Overgray015)
                    .aspectRatio(1, contentMode: .fit)
                    .modifier(ShimmerBackground())
            }
            
            Text("Scan this QR code with your phone")
                .font(.paragraph500)
                .foregroundColor(.Foreground100)
            
            Button(action: {
                UIPasteboard.general.string = store.uri?.absoluteString ?? ""
                store.toast = .init(style: .success, message: "Link copied")
            }, label: {
                Text("Copy Link")
            })
            .buttonStyle(W3MActionEntryStyle(leftIcon: .Bold.copy))
            .disabled(store.uri == nil)
        }
        .padding([.top, .horizontal], Spacing.xl)
        .padding(.bottom, Spacing.l)
        .padding(.bottom)
        .background(Color.Background125)
        .onAppear {
            connect()
        }
    }
    
    private func connect() {
        Task {
            do {
                try await signInteractor.connect(walletUniversalLink: nil)
            } catch {
                store.toast = .init(style: .error, message: "Failed to create connection URI.")
            }
        }
    }
}

struct ConnectWithQRCode_Previews: PreviewProvider {
    static let stubUri: String = Array(repeating: ["a", "b", "c", "1", "2", "3"], count: 30)
        .flatMap { $0 }
        .shuffled()
        .joined()
    
    static let store: Store = {
    
        let store = Store()
        store.uri = WalletConnectURI(
            string: "wc:de631d0009368177ec5b7dd26b5614536f6117c83236c15452f01f0f1c877529@2?symKey=61ee028ff757f897597cc367a4c2f359b34ec615764cae4dea6f41cdff53bf66&relay-protocol=irn"
        )
        
        return store
    }()
    
    static var previews: some View {
        VStack {
            ConnectWithQRCode()
                .environmentObject(store)
                .environmentObject(MockSignInteractor(store: store))
            
            ConnectWithQRCode()
                .environmentObject(Store())
                .environmentObject(MockSignInteractor(store: Store()))
        }
    }
    
    class MockSignInteractor: SignInteractor {
                    
        override func connect(walletUniversalLink: String?) async throws {
            // no-op
        }
    }
}
