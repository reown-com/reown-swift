import SwiftUI
import WalletConnectPay

/// Explainer step shown when the user taps the ⓘ button on a Permit2 option or
/// the "Why does {SYMBOL} require a gas fee?" link on the summary screen.
///
/// Layout matches the existing `PayWhyInfoRequiredView` and the Figma
/// "Why does USDT require a gas fee?" screen — title, body, gas-fee row,
/// "Got it!" CTA. Driven by `presenter.gasFeeOption`.
struct PayGasFeeView: View {
    @EnvironmentObject var presenter: PayPresenter

    private var tokenSymbol: String {
        presenter.gasFeeOption?.amount.display.assetSymbol ?? ""
    }

    private var feeEstimate: FeeEstimate? {
        guard let option = presenter.gasFeeOption else { return nil }
        if case .value(let estimate) = presenter.fee(for: option) { return estimate }
        return nil
    }

    var body: some View {
        PayModalContainer {
            PayHeaderBar(
                showBack: true,
                backAction: { presenter.goBack() },
                closeAction: { presenter.dismiss() },
                backAccessibilityId: "pay-button-back",
                closeAccessibilityId: "pay-button-close"
            )

            Spacer().frame(height: Spacing._5)

            // Token icon header
            if let option = presenter.gasFeeOption {
                TokenIconWithNetwork(
                    iconUrl: option.amount.display.iconUrl,
                    networkIconUrl: option.amount.display.networkIconUrl,
                    symbol: tokenSymbol,
                    size: 64,
                    badgeSize: 24,
                    badgeBorderColor: AppColors.backgroundPrimary
                )
                .padding(.bottom, Spacing._5)
            }

            Text(PaymentReviewFormatter.explainerTitle(tokenSymbol: tokenSymbol))
                .appFont(.h6)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing._3)

            Text(PaymentReviewFormatter.explainerBody(tokenSymbol: tokenSymbol))
                .appFont(.lg)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing._5)

            // Gas fee row
            HStack(spacing: Spacing._2) {
                Text("Gas fee:")
                    .appFont(.lg)
                    .foregroundColor(AppColors.textSecondary)
                if let estimate = feeEstimate {
                    Text(PaymentReviewFormatter.formatFee(estimate))
                        .appFont(.lg)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    ShimmerView(width: 56, height: 14)
                }
                PayGasPumpIcon()
                    .frame(width: 18, height: 18)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.bottom, Spacing._5)

            PayPrimaryButton(
                title: "Got it!",
                isEnabled: true,
                accessibilityId: "pay-gas-fee-got-it",
                action: { presenter.goBack() }
            )
            .padding(.bottom, Spacing._2)
        }
        .accessibilityIdentifier("pay-gas-fee-explainer")
    }
}

#if DEBUG
struct PayGasFeeView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayGasFeeView()
        }
    }
}
#endif
