import SwiftUI

public struct AppKitButton: View {
    @ObservedObject var store: Store
    
    public init() {
        self.store = .shared
    }
    
    init(store: Store = .shared) {
        self.store = store
    }
    
    public var body: some View {
        Group {
            if let _ = store.account {
                AccountButton()
            } else {
                ConnectButton()
            }
        }
    }
}

#if DEBUG

struct AppKitButton_Preview: PreviewProvider {
    static let store = { () -> Store in
        let store = Store()
        store.balance = 1.23
        store.account = .stub
        return store
    }()
    
    static var previews: some View {
        VStack {
            AppKitButton(store: Store())
            
            AppKitButton(store: AppKitButton_Preview.store)
            
            AppKitButton(store: AppKitButton_Preview.store)
                .disabled(true)
        }
    }
}

#endif
