import Foundation
import ReownWalletKit

class SmartAccountEnabler {
    enum Errors: Error {
        case smartAccountNotEnabled
    }

    // Singleton instance
    static let shared = SmartAccountEnabler()

    // Use a private queue for thread-safe access to the isSmartAccountEnabled property
    private let queue = DispatchQueue(label: "com.smartaccount.manager", attributes: .concurrent)

    // A private backing variable for the thread-safe property
    private var _isSmartAccountEnabled: Bool = false

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

    // Private initializer to ensure it cannot be instantiated externally
    private init() {}

    // Function to get smart account addresses
    func getSmartAccountsAddresses(ownerAccount: Account) async throws -> [String] {
        guard isSmartAccountEnabled else {
            throw Errors.smartAccountNotEnabled
        }
        let safeAccount = try await WalletKit.instance.getSmartAccount(ownerAccount: )
        return [safeAccount.address]
    }
}
