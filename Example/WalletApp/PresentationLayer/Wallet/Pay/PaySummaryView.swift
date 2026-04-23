import SwiftUI
import WalletConnectPay

struct PaySummaryView: View {
    @EnvironmentObject var presenter: PayPresenter

    /// Three-state label for the approval fee row:
    ///  - "Loading…" while the gas estimate RPC is in flight,
    ///  - the formatted estimate once it resolves,
    ///  - "Network fee set by wallet" if estimation failed.
    private var approvalFeeText: String {
        if presenter.isEstimatingApprovalGas { return "Loading…" }
        if let estimate = presenter.approvalGasEstimate { return estimate }
        return "Network fee set by wallet"
    }

    var body: some View {
        PayModalContainer {
            // Header: back (left) + X close (right)
            PayHeaderBar(
                showBack: true,
                backAction: { presenter.goBack() },
                closeAction: { presenter.dismiss() },
                backAccessibilityId: "pay-button-back",
                closeAccessibilityId: "pay-button-close"
            )

            if let info = presenter.paymentInfo {
                // Merchant header
                MerchantHeader(info: info)
                    .accessibilityIdentifier("pay-merchant-info")
                    .padding(.top, Spacing._4)

                // "Pay with" row
                if let option = presenter.selectedOption {
                    HStack {
                        Text("Pay with")
                            .appFont(.lg)
                            .foregroundColor(AppColors.textTertiary)

                        Spacer()

                        HStack(spacing: Spacing._2) {
                            Text(option.formattedAmount)
                                .appFont(.lg)
                                .foregroundColor(AppColors.textPrimary)

                            TokenIconWithNetwork(
                                iconUrl: option.amount.display.iconUrl,
                                networkIconUrl: option.amount.display.networkIconUrl,
                                symbol: option.amount.display.assetSymbol,
                                size: 32,
                                badgeBorderColor: AppColors.foregroundPrimary
                            )
                        }
                    }
                    .padding(.horizontal, Spacing._5)
                    .frame(height: 68)
                    .background(AppColors.foregroundPrimary)
                    .cornerRadius(AppRadius._4)
                    .accessibilityIdentifier("pay-review-token-\(option.amount.display.networkName ?? "unknown")")
                    .padding(.top, Spacing._6)
                }

                // One-time approval fee row — shown only when the selected option
                // requires an on-chain approve before the permit signature.
                if presenter.paymentContext?.requiresApproval == true {
                    HStack {
                        Text("One-time fee")
                            .appFont(.lg)
                            .foregroundColor(AppColors.textTertiary)

                        Spacer()

                        Text(approvalFeeText)
                            .appFont(.lg)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.horizontal, Spacing._5)
                    .frame(height: 68)
                    .background(AppColors.foregroundPrimary)
                    .cornerRadius(AppRadius._4)
                    .accessibilityIdentifier("pay-review-one-time-fee")
                    .padding(.top, Spacing._3)
                }

                Spacer()
                    .frame(height: Spacing._5)

                // Pay button — disabled while actions are loading.
                PayPrimaryButton(
                    title: "Pay \(info.formattedAmount)",
                    isEnabled: !presenter.isLoadingActions,
                    accessibilityId: "pay-button-pay",
                    action: { presenter.confirmPayment() }
                )
                .padding(.bottom, Spacing._2)
            }
        }
    }
}

#if DEBUG
struct PaySummaryView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PaySummaryView()
        }
    }
}
#endif
