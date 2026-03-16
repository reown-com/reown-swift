import SwiftUI
import ReownWalletKit

struct VerifyBadgeView: View {
    let status: VerifyContext.ValidationStatus?

    private var config: (label: String, color: Color) {
        switch status {
        case .scam:
            return ("Unsafe", AppColors.textError)
        case .invalid:
            return ("Mismatch", AppColors.textWarning)
        case .valid:
            return ("Verified", AppColors.textSuccess)
        case .unknown, .none:
            return ("Unverified", AppColors.foregroundTertiary)
        }
    }

    var body: some View {
        VerifyBadgeLabel(text: config.label, bgColor: UIColor(config.color))
            .fixedSize()
    }
}

/// UIKit-backed pill for reliable font weight and layout.
private struct VerifyBadgeLabel: UIViewRepresentable {
    let text: String
    let bgColor: UIColor

    func makeUIView(context: Context) -> PaddedLabel {
        let label = PaddedLabel()
        label.textAlignment = .center
        label.clipsToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: PaddedLabel, context: Context) {
        label.text = text
        label.font = UIFont(name: "KHTeka-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = bgColor
        label.layer.cornerRadius = 8
    }
}

/// Label with built-in padding: 8px horizontal, 6px vertical, min height 28px.
private class PaddedLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(width: base.width + 16, height: max(28, base.height + 12))
    }
}
