import SwiftUI

struct AccountButtonStyle: ButtonStyle {
    @ObservedObject var store: Store
    
    public init() {
        self.store = .shared
    }
    
    init(
        store: Store = .shared,
        isPressedOverride: Bool? = nil
    ) {
        self.store = store
        self.isPressedOverride = isPressedOverride
    }
    
    @Environment(\.isEnabled) var isEnabled
    
    var isPressedOverride: Bool?
    
    var addressFormatted: String? {
        guard let address = store.account?.address else {
            return nil
        }
        
        return String(address.prefix(4)) + "..." + String(address.suffix(4))
    }
    
    var selectedChain: Chain {
        return store.selectedChain ?? ChainPresets.ethChains.first!
    }
    
    func makeBody(configuration: Configuration) -> some View {
        var backgroundColor: Color = .GrayGlass002
        let pressedColor: Color = .GrayGlass010
        backgroundColor = (isPressedOverride ?? configuration.isPressed) ? pressedColor : backgroundColor
        backgroundColor = isEnabled ? backgroundColor : .Overgray010
        
        let verticalPadding = Spacing.xxxs
        let leadingPadding = Spacing.xxs
        let trailingPadding = Spacing.xxxs
        
        return Group {
            if store.balance != nil {
                mixedVariant()
            } else {
                accountVariant()
            }
        }
        .padding(.vertical, verticalPadding)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .background(backgroundColor)
        .cornerRadius(Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(Color.Overgray010, lineWidth: 1)
        )
    }
    
    func accountVariant() -> some View {
        var textColor: Color = .Foreground100
        textColor = isEnabled ? textColor : .Overgray015
        
        return HStack(spacing: Spacing.xxs) {
            avatar()
                
            Text(addressFormatted ?? "")
                .font(.paragraph500)
                .foregroundColor(textColor)
        }
        .padding(Spacing.xs)
        .cornerRadius(Radius.m)
    }
    
    func mixedVariant() -> some View {
        var textColor: Color = .Foreground100
        textColor = isEnabled ? textColor : .Overgray015
        
        var textColorInner: Color = .Foreground200
        textColorInner = isEnabled ? textColorInner : .Overgray010
        
        return HStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                networkImage()
                
                let balance = store.balance?.roundedDecimal(to: 4, mode: .down) ?? 0
                
                Text(balance == 0 ? "0 \(selectedChain.token.symbol)" : "\(balance, specifier: "%.3f") \(selectedChain.token.symbol)")
                    .font(.paragraph600)
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            
            HStack(spacing: Spacing.xxs) {
                avatar()
                
                Text(addressFormatted ?? "")
                    .font(.paragraph500)
                    .foregroundColor(textColorInner)
            }
            .padding(Spacing.xs)
            .background(Color.GrayGlass005)
            .cornerRadius(Radius.m)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(Color.Overgray010, lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    func networkImage() -> some View {
        Group {
            if let storedImage = store.chainImages[selectedChain.imageId] {
                Image(uiImage: storedImage)
                    .resizable()
            } else {
                Image.Regular.network
                    .resizable()
                    .padding(Spacing.xxs)
            }
        }
        .saturation(isEnabled ? 1 : 0)
        .opacity(isEnabled ? 1 : 0.5)
        .frame(width: 24, height: 24)
        .clipShape(Circle())
        .overlay(Circle().stroke(.Overgray005, lineWidth: 2))
    }
    
    @ViewBuilder
    func avatar() -> some View {
        Group {
            if let avatarUrlString = store.identity?.avatar, let url = URL(string: avatarUrlString) {
                Backport.AsyncImage(url: url)
            } else if let address = store.account?.address {
                W3MAvatarGradient(address: address)
            }
        }
        .saturation(isEnabled ? 1 : 0)
        .opacity(isEnabled ? 1 : 0.5)
        .frame(width: 20, height: 20)
        .clipShape(Circle())
        .overlay(Circle().stroke(.GrayGlass010, lineWidth: 3))
    }
}

public struct AccountButton: View {
    let store: Store
    let blockchainApiInteractor: BlockchainAPIInteractor
    
    public init() {
        self.store = .shared
        self.blockchainApiInteractor = BlockchainAPIInteractor(store: .shared)
    }
    
    init(store: Store = .shared, blockchainApiInteractor: BlockchainAPIInteractor) {
        self.store = store
        self.blockchainApiInteractor = blockchainApiInteractor
    }
    
    public var body: some View {
        Button(action: {
            Web3Modal.present()
        }, label: {})
            .buttonStyle(AccountButtonStyle(store: store))
            .onAppear {
                fetchIdentity()
                fetchBalance()
            }
    }
    
    func fetchIdentity() {
        Task { @MainActor in
            do {
                try await blockchainApiInteractor.getIdentity()
            } catch {
                store.toast = .init(style: .error, message: "Network error")
                Web3Modal.config.onError(error)
            }
        }
    }
    
    func fetchBalance() {
        Task { @MainActor in
            do {
                try await blockchainApiInteractor.getBalance()
            } catch {
                store.toast = .init(style: .error, message: "Network error")
                Web3Modal.config.onError(error)
            }
        }
    }
}

#if DEBUG

public struct AccountButtonPreviewView: View {
    public init() {}
    
    static let store = { (balance: Double?) -> Store in
        let store = Store()
        store.balance = balance
        store.session = .stub
        store.account = W3MAccount(
            address: Session.stub.accounts.first!.address,
            chain: Session.stub.accounts.first!.blockchain
        )
    
        return store
    }
    
    static let blockchainInteractor = { () -> BlockchainAPIInteractor in
        MockBlockchainAPIInteractor()
    }
    
    public var body: some View {
        VStack {
            AccountButton(
                store: AccountButtonPreviewView.store(1.23),
                blockchainApiInteractor: MockBlockchainAPIInteractor()
            )
            
            AccountButton(
                store: AccountButtonPreviewView.store(nil),
                blockchainApiInteractor: MockBlockchainAPIInteractor()
            )
            
            AccountButton(
                store: AccountButtonPreviewView.store(1.23),
                blockchainApiInteractor: MockBlockchainAPIInteractor()
            )
            .disabled(true)
            
            AccountButton(
                store: AccountButtonPreviewView.store(nil),
                blockchainApiInteractor: MockBlockchainAPIInteractor()
            )
            .disabled(true)
            
            Button(action: {}, label: {})
                .buttonStyle(
                    AccountButtonStyle(
                        store: AccountButtonPreviewView.store(1.23),
                        isPressedOverride: true
                    )
                )
            
            Button(action: {}, label: {})
                .buttonStyle(
                    AccountButtonStyle(
                        store: AccountButtonPreviewView.store(nil),
                        isPressedOverride: true
                    )
                )
        }
    }
}

struct AccountButton_Preview: PreviewProvider {
    static var previews: some View {
        AccountButtonPreviewView()
    }
}

#endif
