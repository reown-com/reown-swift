import SwiftUI
import WalletConnectPay

struct PaySummaryView: View {
    @EnvironmentObject var presenter: PayPresenter

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

                Spacer()
                    .frame(height: Spacing._5)

                // Pay button
                PayPrimaryButton(
                    title: "Pay \(info.formattedAmount)",
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
