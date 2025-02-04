import Foundation
import ReownWalletKit

class WalletKitEnabler {
    enum Errors: LocalizedError {
        case smartAccountNotEnabled
    }

    // Singleton instance
    static let shared = WalletKitEnabler()

    // Use a private queue for thread-safe access to properties
    private let queue = DispatchQueue(label: "com.smartaccount.manager", attributes: .concurrent)

    // Private backing variables
    private var _isChainAbstractionEnabled: Bool = true

    // Thread-safe access for isChainAbstractionEnabled
    var isChainAbstractionEnabled: Bool {
        get {
            return queue.sync {
                _isChainAbstractionEnabled
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._isChainAbstractionEnabled = newValue
            }
        }
    }

    // Private initializer to ensure it cannot be instantiated externally
    private init() {}

}
