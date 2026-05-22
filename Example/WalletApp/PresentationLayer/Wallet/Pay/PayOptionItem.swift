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
            PayInfoIcon()
                .frame(width: 20, height: 20)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing._3)
                        .stroke(AppColors.borderSecondary, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture { action() }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Info")
                .accessibilityIdentifier(id ?? "")
        case .pencil(let action, let id):
            PayPencilIcon()
                .frame(width: 18, height: 18)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing._3)
                        .stroke(AppColors.borderSecondary, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture { action() }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Edit")
                .accessibilityIdentifier(id ?? "")
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
