import Foundation
import ReownWalletKit

class WalletKitEnabler {
    enum Errors: Error {
        case smartAccountNotEnabled
    }

    // Singleton instance
    static let shared = WalletKitEnabler()

    // Use a private queue for thread-safe access to properties
    private let queue = DispatchQueue(label: "com.smartaccount.manager", attributes: .concurrent)

    // A private backing variable for the thread-safe properties
    private var _isSmartAccountEnabled: Bool = false
    private var _isChainAbstractionEnabled: Bool = true

    // Thread-safe access for setting and getting isSmartAccountEnabled
    var isSmartAccountEnabled: Bool {
        get {
            return queue.sync {
                _isSmartAccountEnabled
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._isSmartAccountEnabled = newValue
            }
        }
    }

    // Thread-safe access for setting and getting isChainAbstractionEnabled
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

    // Function to get smart account addresses
    func getSmartAccountsAddresses(ownerAccount: Account) async throws -> [String] {
        guard isSmartAccountEnabled else {
            throw Errors.smartAccountNotEnabled
        }
        let safeAccount = try await WalletKit.instance.getSmartAccount(ownerAccount: ownerAccount)
        return [safeAccount.address]
    }
}
