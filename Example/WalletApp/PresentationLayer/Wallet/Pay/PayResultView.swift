import SwiftUI

/// Error type classification matching RN's ResultView error states
enum PayResultType {
    case success
    case insufficientFunds
    case expired
    case notFound
    case generic(message: String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Unified result screen for both success and error states.
/// Matches RN's `ResultView.tsx` pattern.
struct PayResultView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        PayModalContainer {
            // Close button
            HStack {
                Spacer()
                PayCloseButton(action: { presenter.dismiss() })
            }
            .padding(.top, Spacing._4)

            Spacer()
                .frame(height: Spacing._7)

            // Icon (not animated, matches RN)
            iconView

            Spacer()
                .frame(height: Spacing._4)

            // Title
            Text(title)
                .appFont(.h6)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Message (error states only)
            if let message = message {
                Text(message)
                    .appFont(.lg)
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.top, Spacing._1)
            }

            Spacer()
                .frame(height: Spacing._7)

            // Action button
            PayPrimaryButton(
                title: buttonTitle,
                action: { presenter.dismiss() }
            )

            Spacer()
                .frame(height: Spacing._2)
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconView: some View {
        switch presenter.resultType {
        case .success:
            CheckCircleShape()
                .fill(AppColors.textSuccess)
                .frame(width: 40, height: 40)

        case .insufficientFunds:
            CoinStackShape()
                .fill(AppColors.iconAccentPrimary)
                .frame(width: 40, height: 40)

        case .expired, .notFound, .generic:
            WarningCircleShape()
                .fill(AppColors.iconAccentPrimary)
                .frame(width: 40, height: 40)
        }
    }

    // MARK: - Text Content

    private var title: String {
        switch presenter.resultType {
        case .success:
            let amount = presenter.paymentInfo?.formattedAmount ?? "$0.00"
            let merchant = presenter.paymentInfo?.merchant.name ?? "Merchant"
            return "You've paid \(amount) to \(merchant)"
        case .insufficientFunds:
            return "Not enough funds"
        case .expired:
            return "Payment expired"
        case .notFound:
            return "Payment not found"
        case .generic:
            return "Transaction failed"
        }
    }

    private var message: String? {
        switch presenter.resultType {
        case .success:
            return nil
        case .insufficientFunds:
            return "You don't have enough crypto to complete this payment."
        case .expired:
            return "This payment took too long to approve and has expired."
        case .notFound:
            return "This payment link is not valid or has already been completed."
        case .generic(let msg):
            return msg.isEmpty ? "The network couldn't complete this transaction." : msg
        }
    }

    private var buttonTitle: String {
        switch presenter.resultType {
        case .success, .insufficientFunds:
            return "Got it!"
        case .expired:
            return "Scan new QR code"
        case .notFound, .generic:
            return "Close"
        }
    }

}

#if DEBUG
struct PayResultView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayResultView()
        }
    }
}
#endif
