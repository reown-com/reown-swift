import SwiftUI
import WalletConnectPay

/// Right-side slot of an `OptionItem`. Drives both the icon and tap target.
enum OptionRightSlot {
    case none
    /// ⓘ button — used on the select screen to open the gas explainer for
    /// approval-bearing options without changing selection.
    case info(action: () -> Void, accessibilityId: String?)
    /// ✏︎ button — used on the review/summary screen to step back to options.
    case pencil(action: () -> Void, accessibilityId: String?)
}

/// Shared payment-option row used in both the select screen and the review
/// (summary) screen. Mirrors RN PR #480 / Kotlin PR #385's shared `OptionItem`.
///
/// Selection state was removed when the options screen moved to tap-to-advance:
/// every row renders the same neutral background, with no accent ring or
/// indicator dot.
struct OptionItem: View {
    let option: PaymentOption
    let feeState: FeeState
    let rightSlot: OptionRightSlot
    var accessibilityId: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        let bgColor = AppColors.foregroundPrimary

        HStack(spacing: Spacing._2) {
            TokenIconWithNetwork(
                iconUrl: option.amount.display.iconUrl,
                networkIconUrl: option.amount.display.networkIconUrl,
                symbol: option.amount.display.assetSymbol,
                size: 32,
                badgeSize: 18,
                badgeBorderColor: bgColor
            )

            Text(option.formattedAmount)
                .appFont(.lg)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            feeSuffix

            rightSlotView
        }
        .padding(.horizontal, Spacing._5)
        .frame(height: 68)
        .background(bgColor)
        .cornerRadius(AppRadius._4)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityIdentifier(accessibilityId ?? "")
        .accessibilityLabel(option.amount.display.networkName ?? "unknown")
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var feeSuffix: some View {
        switch feeState {
        case .notRequired, .unavailable:
            EmptyView()
        case .loading:
            HStack(spacing: Spacing._1) {
                ShimmerView(width: 44, height: 12)
                PayGasPumpIcon()
                    .frame(width: 18, height: 18)
                    .foregroundColor(AppColors.textSecondary)
            }
        case .value(let estimate):
            HStack(spacing: Spacing._1) {
                Text(PaymentReviewFormatter.feeRowSuffix(estimate))
                    .appFont(.lg)
                    .foregroundColor(AppColors.textSecondary)
                PayGasPumpIcon()
                    .frame(width: 18, height: 18)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var rightSlotView: some View {
        switch rightSlot {
        case .none:
            EmptyView()
        case .info(let action, let id):
            OptionSlotButton(
                imageName: "PayInfo",
                iconSize: 20,
                buttonSize: 38,
                accessibilityId: id ?? "",
                accessibilityLabel: "Info",
                action: action
            )
            .frame(width: 38, height: 38)
        case .pencil(let action, let id):
            OptionSlotButton(
                imageName: "PayPencil",
                iconSize: 18,
                buttonSize: 38,
                accessibilityId: id ?? "",
                accessibilityLabel: "Edit",
                action: action
            )
            .frame(width: 38, height: 38)
        }
    }
}

// MARK: - ShimmerView

/// A lightweight time-driven shimmer. No external dependencies — uses
/// `TimelineView` + a linear gradient sweeping across a rounded rect.
struct ShimmerView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let phase = phase(at: context.date)
            let base = AppColors.foregroundTertiary
            let highlight = AppColors.foregroundSecondary
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(base)
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [base.opacity(0), highlight.opacity(0.7), base.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
                    .mask(RoundedRectangle(cornerRadius: 4))
            }
            .frame(width: width, height: height)
        }
    }

    private func phase(at date: Date) -> CGFloat {
        let period: TimeInterval = 1.2
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return CGFloat(progress) * (width * 2) - width
    }
}

// MARK: - Pay SVG-asset icons

/// Gas-pump glyph rendered from the `PayGasPump` SVG asset (template-tinted).
struct PayGasPumpIcon: View {
    var body: some View {
        Image("PayGasPump")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

/// Pencil glyph (review-screen "edit token") rendered from the `PayPencil` SVG
/// asset (template-tinted).
struct PayPencilIcon: View {
    var body: some View {
        Image("PayPencil")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

/// Filled info glyph rendered from the `PayInfo` SVG asset (template-tinted).
struct PayInfoIcon: View {
    var body: some View {
        Image("PayInfo")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

// MARK: - OptionSlotButton (UIKit-backed for reliable Maestro identifiers)

/// UIKit `UIButton` wrapper used by `OptionItem`'s right slot. Pure SwiftUI
/// Buttons nested inside an `.accessibilityElement(children: .contain)` row
/// don't reliably expose their `accessibilityIdentifier` to XCUITest, so the
/// info / edit affordances Maestro needs to tap (e.g. `pay-option-info-required`)
/// are rendered through this representable to guarantee a native UIView carries
/// the id directly.
struct OptionSlotButton: UIViewRepresentable {
    let imageName: String
    let iconSize: CGFloat
    let buttonSize: CGFloat
    let accessibilityId: String
    let accessibilityLabel: String
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = UIColor.label
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.separator.cgColor
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        button.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        configure(button: button, context: context)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.action = action
        configure(button: button, context: context)
    }

    private func configure(button: UIButton, context: Context) {
        let inset = max(0, (buttonSize - iconSize) / 2)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
            config.contentInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
            config.background.backgroundColor = .clear
            button.configuration = config
        } else {
            button.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
            button.imageEdgeInsets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        }
        button.accessibilityIdentifier = accessibilityId
        button.accessibilityLabel = accessibilityLabel
    }

    final class Coordinator {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}
