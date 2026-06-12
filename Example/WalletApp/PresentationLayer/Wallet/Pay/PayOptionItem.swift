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
        ZStack(alignment: .trailing) {
            rowSurface

            if hasRightSlot {
                rightSlotView
                    .padding(.trailing, Spacing._5)
            }
        }
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

    private var hasRightSlot: Bool {
        switch rightSlot {
        case .none:
            false
        case .info, .pencil:
            true
        }
    }

    private var rowAccessibilityLabel: String {
        (option.amount.display.networkName ?? "unknown").lowercased()
    }

    private var trailingAccessoryWidth: CGFloat {
        hasRightSlot ? 38 + Spacing._2 : 0
    }

    @ViewBuilder
    private var rowSurface: some View {
        if let onTap {
            Button(action: onTap) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowAccessibilityLabel)
            .accessibilityIdentifier(accessibilityId ?? "")
        } else {
            rowContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rowAccessibilityLabel)
                .accessibilityIdentifier(accessibilityId ?? "")
        }
    }

    private var rowContent: some View {
        let bgColor = AppColors.foregroundPrimary

        return HStack(spacing: Spacing._2) {
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
        }
        .padding(.leading, Spacing._5)
        .padding(.trailing, Spacing._5 + trailingAccessoryWidth)
        .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 68, alignment: .leading)
        .background(bgColor)
        .cornerRadius(AppRadius._4)
        .contentShape(Rectangle())
    }
}

// MARK: - Stable option accessibility id

extension PaymentOption {
    /// Stable, network+token-keyed id segment for Maestro selection
    /// (e.g. `usdt-polygon`): `assetSymbol-networkName`, lowercased with
    /// whitespace collapsed to dashes. Mirrors the RN consumer
    /// (react-native-examples #533) so the shared `pay_usdt_polygon` flow can
    /// pick a specific asset+network when a token appears on several networks.
    var stableOptionIdSuffix: String {
        let symbol = amount.display.assetSymbol
        let network = amount.display.networkName ?? "unknown"
        return "\(symbol)-\(network)"
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
    }
}

// MARK: - Maestro accessibility marker

/// Non-interactive native accessibility element used to give a SwiftUI view an
/// *additional* Maestro-addressable id. Overlaid on a payment-option row, it
/// exposes the stable `pay-option-{symbol}-{network}` id alongside the
/// order-dependent `pay-option-{index}` carried by the row button itself.
///
/// It doesn't consume touches (`isUserInteractionEnabled = false`), so Maestro's
/// tap at the marker's frame centre falls through to the row button beneath —
/// the same effect as RN's outer `<View testID=…>` wrapper. A plain SwiftUI
/// `.accessibilityIdentifier(...)` on a wrapper isn't reliably surfaced to
/// XCUITest (see CLAUDE.md), so we back it with a real `UIView`.
struct MaestroAccessibilityMarker: UIViewRepresentable {
    let identifier: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityTraits = .button
        view.accessibilityIdentifier = identifier
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        view.accessibilityIdentifier = identifier
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

/// UIKit `UIButton` wrapper used by `OptionItem`'s right slot. The row itself
/// remains a separate accessibility element/button, so the info/edit affordance
/// needs its own native UIView to keep identifiers like
/// `pay-option-info-required` independently addressable to XCUITest/Maestro.
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
