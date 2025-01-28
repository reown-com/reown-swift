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
    private var _isSmartAccountEnabled: Bool = false
    private var _isChainAbstractionEnabled: Bool = true
    private var _is7702AccountEnabled: Bool = true

    // Thread-safe access for isSmartAccountEnabled
    var isSmartAccountEnabled: Bool {
        get {
            return queue.sync {
                _isSmartAccountEnabled
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._isSmartAccountEnabled = newValue
                if newValue {
                    self._is7702AccountEnabled = false
                }
            }
        }
    }

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

    // Thread-safe access for is7702AccountEnabled
    var is7702AccountEnabled: Bool {
        get {
            return queue.sync {
                _is7702AccountEnabled
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._is7702AccountEnabled = newValue
                if newValue {
                    self._isSmartAccountEnabled = false
                }
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
