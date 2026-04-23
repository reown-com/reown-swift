import Foundation
import WalletConnectPay

struct PaymentContext {
    let approvalAction: Action?

    var requiresApproval: Bool { approvalAction != nil }
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
}
