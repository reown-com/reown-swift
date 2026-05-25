import Foundation
import BigInt
import WalletConnectPay

struct PaymentContext {
    let approvalAction: Action?

    var requiresApproval: Bool { approvalAction != nil }
}

/// Native + fiat representation of a one-time approval fee.
struct FeeEstimate {
    let nativeWei: BigUInt
    let nativeAmount: Double
    let nativeSymbol: String
    let fiatAmount: Double?
    let fiatCurrency: String
}

/// Per-option fee preload state surfaced to the views.
enum FeeState {
    case notRequired
    case loading
    case value(FeeEstimate)
    case unavailable
}

enum PaymentUtil {
    /// Returns the payment context for a list of wallet RPC actions.
    /// The approval action is the first `eth_sendTransaction` in the list — mirrors
    /// `src/utils/PaymentUtil.ts` from `reown-com/react-native-examples#472`.
    static func getPaymentContext(actions: [Action]?) -> PaymentContext {
        guard let actions else { return PaymentContext(approvalAction: nil) }
        let approval = actions.first { $0.walletRpc.method == "eth_sendTransaction" }
        return PaymentContext(approvalAction: approval)
    }

    /// True if the option's action chain begins with an on-chain approval.
    /// Driven entirely off `PaymentOption.actions` returned by `getPaymentOptions`
    /// — no committal RPC call is needed for this prediction.
    static func requiresApproval(option: PaymentOption) -> Bool {
        option.actions.contains { $0.walletRpc.method == "eth_sendTransaction" }
    }

    /// Multi-step flows (approval + signature) get a dedicated one-time-setup
    /// loader during confirm. Single-step flows don't.
    static func shouldShowSetupLoader(actions: [Action]) -> Bool {
        actions.count > 1 && actions.contains { $0.walletRpc.method == "eth_sendTransaction" }
    }
}
