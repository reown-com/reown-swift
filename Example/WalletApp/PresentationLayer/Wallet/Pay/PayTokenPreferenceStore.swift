import Foundation
import WalletConnectPay

/// Persists the `amount.unit` of the option the user most recently paid with so
/// the same token can be pre-selected on the next payment.
///
/// Mirrors RN PR #480's `PAY_LAST_TOKEN_UNIT` MMKV entry and Kotlin's
/// `PaymentTokenPreferenceStore`. Cleared on wallet import.
struct PayTokenPreferenceStore {
    static let key = "PAY_LAST_TOKEN_UNIT"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastPaidTokenUnit: String? {
        get { defaults.string(forKey: Self.key) }
        set {
            if let v = newValue, !v.isEmpty {
                defaults.set(v, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    /// Returns the first option whose `amount.unit` matches `lastPaidUnit`, or
    /// `nil` if no match exists in the current options. The caller is expected
    /// to fall back to its own default selection (typically `.first`).
    static func findPreferredOption(_ options: [PaymentOption], lastPaidUnit: String?) -> PaymentOption? {
        guard let unit = lastPaidUnit, !unit.isEmpty else { return nil }
        return options.first { $0.amount.unit == unit }
    }
}
