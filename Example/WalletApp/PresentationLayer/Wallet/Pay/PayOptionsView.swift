import SwiftUI
import WalletConnectPay

struct PayOptionsView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        PayModalContainer {
            // Header: X close only. The per-row ⓘ now carries the
            // "Why do we collect personal details?" entry point so the
            // top-level question button is gone.
            HStack {
                Spacer()
                PayCloseButton(action: { presenter.dismiss() }, accessibilityId: "pay-button-close")
            }
            .padding(.top, Spacing._5)

            // Centered token-stack icon + title — replaces the previous
            // MerchantHeader.
            VStack(spacing: Spacing._4) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius._4)
                        .fill(AppColors.foregroundAccentPrimary10Solid)
                        .frame(width: 64, height: 64)
                    CoinStackShape()
                        .fill(AppColors.foregroundAccentPrimary90Solid)
                        .frame(width: 36, height: 36)
                }

                Text("Select a token to pay with")
                    .appFont(.h6)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("pay-select-option-header")
            }
            .padding(.top, Spacing._5)

            // Payment options list — tap a row to advance directly to review.
            // There is no Continue button; row selection and confirmation are
            // the same gesture.
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing._2) {
                    ForEach(Array(presenter.paymentOptions.enumerated()), id: \.element.id) { index, option in
                        let needsIC = option.collectData != nil || presenter.anyOptionRequiresIC
                        let rightSlot: OptionRightSlot = needsIC
                            ? .info(action: { presenter.showWhyInfoRequiredScreen() },
                                    accessibilityId: "pay-option-info-required")
                            : .none
                        OptionItem(
                            option: option,
                            feeState: presenter.fee(for: option),
                            rightSlot: rightSlot,
                            accessibilityId: "pay-option-\(index)",
                            onTap: {
                                presenter.selectOption(option)
                                presenter.continueFromOptions()
                            }
                        )
                        .overlay(
                            MaestroAccessibilityMarker(
                                identifier: "pay-option-\(option.stableOptionIdSuffix)"
                            )
                            .allowsHitTesting(false)
                        )
                    }
                }
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
            .padding(.top, Spacing._5)

            // Footer: "Pay {amount} to {merchant}" + small merchant icon.
            if let info = presenter.paymentInfo {
                merchantFooter(info: info)
                    .padding(.top, Spacing._4)
                    .padding(.bottom, Spacing._2)
                    .accessibilityIdentifier("pay-merchant-info")
            }
        }
    }

    private func merchantFooter(info: PaymentInfo) -> some View {
        HStack(spacing: Spacing._2) {
            Text("Pay \(info.formattedAmount) to \(info.merchant.name)")
                .appFont(.lg)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let iconUrl = info.merchant.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        EmptyView()
                    }
                }
                .frame(width: 20, height: 20)
                .cornerRadius(AppRadius._1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Merchant Header (still used by PaySummaryView)

struct MerchantHeader: View {
    let info: PaymentInfo

    var body: some View {
        VStack(spacing: Spacing._4) {
            // Merchant icon — 64x64 with border-radius 16px
            if let iconUrl = info.merchant.iconUrl {
                AsyncImage(url: URL(string: iconUrl)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        merchantPlaceholder(name: info.merchant.name)
                    }
                }
                .frame(width: 64, height: 64)
                .cornerRadius(AppRadius._4)
            } else {
                merchantPlaceholder(name: info.merchant.name)
                    .frame(width: 64, height: 64)
            }

            // "Pay {amount} to {merchant}" — h6-400, single line, centered
            Text("Pay \(info.formattedAmount) to \(info.merchant.name)")
                .appFont(.h6)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
    }

    private func merchantPlaceholder(name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius._4)
                .fill(AppColors.foregroundTertiary)
            Text(String(name.prefix(1)))
                .appFont(.h5, weight: .medium)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

// MARK: - Token Icon With Network Badge

struct TokenIconWithNetwork: View {
    let iconUrl: String?
    let networkIconUrl: String?
    let symbol: String
    let size: CGFloat
    var badgeSize: CGFloat = 16
    var isSelected: Bool = false
    var badgeBorderColor: Color?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TokenIcon(iconUrl: iconUrl, symbol: symbol, size: size)

            if let networkIconUrl = networkIconUrl, let url = URL(string: networkIconUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        EmptyView()
                    }
                }
                .frame(width: badgeSize, height: badgeSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            badgeBorderColor ?? (isSelected ? AppColors.foregroundAccentPrimary10Solid : AppColors.foregroundSecondary),
                            lineWidth: 2
                        )
                )
                .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: - Token Icon

struct TokenIcon: View {
    let iconUrl: String?
    let symbol: String
    let size: CGFloat

    var body: some View {
        if let iconUrl = iconUrl, let url = URL(string: iconUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    tokenPlaceholder
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                @unknown default:
                    tokenPlaceholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            tokenPlaceholder
        }
    }

    private var tokenPlaceholder: some View {
        ZStack {
            Circle()
                .fill(AppColors.foregroundPrimary)
            Text(String(symbol.prefix(1)))
                .appFont(.md, weight: .medium)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Info Required Pill (UIKit-backed for reliable font weight)

struct InfoRequiredPill: UIViewRepresentable {
    let isSelected: Bool
    let accessibilityId: String?

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = "Info required"
        label.textAlignment = .center
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.isAccessibilityElement = true
        label.accessibilityLabel = "Info required"
        label.accessibilityIdentifier = accessibilityId
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.font = UIFont(name: "KHTeka-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        let textInvert = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x202020) : UIColor(hex: 0xFFFFFF) }
        let textPrimary = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xFFFFFF) : UIColor(hex: 0x202020) }
        label.textColor = isSelected ? textInvert : textPrimary
        label.accessibilityIdentifier = accessibilityId
    }
}

// MARK: - Info Required Pill Wrapper

struct InfoRequiredPillView: View {
    let isSelected: Bool
    let accessibilityId: String?

    var body: some View {
        InfoRequiredPill(isSelected: isSelected, accessibilityId: accessibilityId)
            .fixedSize()
            .padding(.horizontal, Spacing._2)
            .padding(.vertical, 6)
            .background(isSelected ? AppColors.foregroundAccentPrimary90Solid : AppColors.foregroundTertiary)
            .cornerRadius(AppRadius._2)
    }
}

#if DEBUG
struct PayOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayOptionsView()
        }
    }
}
#endif
