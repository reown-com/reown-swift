import SwiftUI
import WalletConnectPay

struct PaySummaryView: View {
    @EnvironmentObject var presenter: PayPresenter

    private var selectedFeeEstimate: FeeEstimate? {
        guard let option = presenter.selectedOption else { return nil }
        if case .value(let estimate) = presenter.fee(for: option) { return estimate }
        return nil
    }

    private var requiresApprovalForSelected: Bool {
        guard let option = presenter.selectedOption else { return false }
        return presenter.requiresApproval(for: option)
    }

    private var canGoBackToOptions: Bool {
        presenter.paymentOptions.count > 1 && !presenter.summaryEnteredDirectly
    }

    var body: some View {
        PayModalContainer {
            // Header: back (only when multiple options) + X close
            PayHeaderBar(
                showBack: canGoBackToOptions,
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

                if let option = presenter.selectedOption {
                    // Pencil stays available whenever there are multiple
                    // options to switch between, even if we entered review
                    // directly via the remembered-token shortcut.
                    let rightSlot: OptionRightSlot = presenter.paymentOptions.count > 1
                        ? .pencil(action: { presenter.currentStep = .options },
                                  accessibilityId: "pay-review-edit-token")
                        : .none
                    OptionItem(
                        option: option,
                        feeState: requiresApprovalForSelected ? presenter.fee(for: option) : .notRequired,
                        rightSlot: rightSlot,
                        accessibilityId: "pay-review-token-\(option.amount.display.networkName ?? "unknown")"
                    )
                    .padding(.top, Spacing._6)
                }

                Spacer()
                    .frame(height: Spacing._5)

                PayPrimaryButton(
                    title: PaymentReviewFormatter.payButtonLabel(merchantInfo: info, fee: selectedFeeEstimate),
                    isEnabled: presenter.selectedOption != nil,
                    accessibilityId: "pay-button-pay",
                    action: { presenter.confirmPayment() }
                )
                .padding(.bottom, Spacing._2)

                if requiresApprovalForSelected,
                   let estimate = selectedFeeEstimate,
                   let fiat = estimate.fiatAmount, fiat > 0,
                   let symbol = presenter.selectedOption?.amount.display.assetSymbol {
                    Button(action: {
                        if let option = presenter.selectedOption {
                            presenter.showGasFeeExplainer(for: option)
                        }
                    }) {
                        Text(PaymentReviewFormatter.explainerLinkLabel(tokenSymbol: symbol))
                            .appFont(.md)
                            .foregroundColor(AppColors.textSecondary)
                            .underline()
                    }
                    .accessibilityIdentifier("pay-review-gas-fee-link")
                }
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
