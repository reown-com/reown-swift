import SwiftUI
import UIKit

/// Error type classification matching RN's ResultView error states
enum PayResultType {
    case success
    case insufficientFunds
    case expired
    case cancelled
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
                PayCloseButton(action: { presenter.dismiss() }, accessibilityId: "pay-button-close")
            }
            .padding(.top, Spacing._4)

            Spacer()
                .frame(height: Spacing._7)

            // Icon (not animated, matches RN)
            ResultIconImageView(
                image: iconImage,
                accessibilityId: iconAccessibilityId,
                accessibilityLabel: iconAccessibilityLabel
            )
            .frame(width: 40, height: 40)

            Spacer()
                .frame(height: Spacing._4)

            // Title
            Text(title)
                .appFont(.h6)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .accessibilityIdentifier("pay-result-title")

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
                accessibilityId: buttonAccessibilityId,
                action: { presenter.dismiss() }
            )

            Spacer()
                .frame(height: Spacing._2)
        }
        .accessibilityIdentifier("pay-result-container")
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconSourceView: some View {
        switch presenter.resultType {
        case .success:
            CheckCircleShape()
                .fill(AppColors.textSuccess)
                .frame(width: 40, height: 40)

        case .insufficientFunds:
            CoinStackShape()
                .fill(AppColors.iconAccentPrimary)
                .frame(width: 40, height: 40)

        case .cancelled, .expired, .notFound, .generic:
            WarningCircleShape()
                .fill(AppColors.iconAccentPrimary)
                .frame(width: 40, height: 40)
        }
    }

    private var iconImage: UIImage? {
        let renderer = ImageRenderer(content: iconSourceView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 40, height: 40)
        return renderer.uiImage
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
        case .cancelled:
            return "Payment cancelled"
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
        case .cancelled:
            return "This payment was cancelled."
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
        case .cancelled:
            return "Close"
        case .notFound, .generic:
            return "Close"
        }
    }

    // MARK: - Accessibility IDs

    private var iconAccessibilityId: String {
        switch presenter.resultType {
        case .success:
            return "pay-result-success-icon"
        case .insufficientFunds:
            return "pay-result-insufficient-funds-icon"
        case .expired:
            return "pay-result-expired-icon"
        case .cancelled:
            return "pay-result-cancelled-icon"
        case .notFound, .generic:
            return "pay-result-error-icon"
        }
    }

    private var iconAccessibilityLabel: String {
        switch presenter.resultType {
        case .success:
            return "Success"
        case .insufficientFunds:
            return "Insufficient funds"
        case .expired:
            return "Expired"
        case .cancelled:
            return "Cancelled"
        case .notFound, .generic:
            return "Error"
        }
    }

    private var buttonAccessibilityId: String {
        switch presenter.resultType {
        case .success:
            return "pay-button-result-action-success"
        case .insufficientFunds:
            return "pay-button-result-action-insufficient_funds"
        case .expired:
            return "pay-button-result-action-expired"
        case .cancelled:
            return "pay-button-result-action-cancelled"
        case .notFound, .generic:
            return "pay-button-result-action-generic"
        }
    }

}

private struct ResultIconImageView: UIViewRepresentable {
    let image: UIImage?
    let accessibilityId: String
    let accessibilityLabel: String

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        imageView.accessibilityIdentifier = accessibilityId
        imageView.accessibilityLabel = accessibilityLabel
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.image = image
        imageView.accessibilityIdentifier = accessibilityId
        imageView.accessibilityLabel = accessibilityLabel
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
