import SwiftUI
import WalletConnectPay

struct PayOptionsView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        PayModalContainer {
            // Header: ? button (left) + X close (right)
            HStack {
                if presenter.anyOptionRequiresIC {
                    PayQuestionButton(action: {
                        presenter.showWhyInfoRequiredScreen()
                    })
                    .accessibilityIdentifier("pay-button-info")
                }

                Spacer()

                PayCloseButton(action: { presenter.dismiss() }, accessibilityId: "pay-button-close")
            }
            .padding(.top, Spacing._5)

            if let info = presenter.paymentInfo {
                // Merchant icon (no seal check)
                MerchantHeader(info: info)
                    .accessibilityIdentifier("pay-merchant-info")
                    .padding(.top, Spacing._5)

                // Payment options list
                VStack(spacing: Spacing._2) {
                    ForEach(Array(presenter.paymentOptions.enumerated()), id: \.element.id) { index, option in
                        let isSelected = presenter.selectedOption?.id == option.id
                        PaymentOptionCard(
                            option: option,
                            isSelected: isSelected,
                            requiresIC: presenter.anyOptionRequiresIC,
                            accessibilityId: isSelected ? "pay-option-\(index)-selected" : "pay-option-\(index)",
                            onSelect: { presenter.selectOption(option) }
                        )
                    }
                }
                .padding(.top, Spacing._7)

                // Primary button
                PayPrimaryButton(
                    title: presenter.optionsButtonTitle,
                    isEnabled: presenter.selectedOption != nil,
                    accessibilityId: "pay-button-continue",
                    action: { presenter.continueFromOptions() }
                )
                .padding(.top, Spacing._5)
            }
        }
    }
}

// MARK: - Merchant Header

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

// MARK: - Payment Option Card

struct PaymentOptionCard: View {
    let option: PaymentOption
    let isSelected: Bool
    let requiresIC: Bool
    let accessibilityId: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing._2) {
                // Token icon 32x32 with network badge 18x18
                TokenIconWithNetwork(
                    iconUrl: option.amount.display.iconUrl,
                    networkIconUrl: option.amount.display.networkIconUrl,
                    symbol: option.amount.display.assetSymbol,
                    size: 32,
                    badgeSize: 18,
                    isSelected: isSelected
                )

                // Token amount — lg-400 (16px, 400)
                Text(option.formattedAmount)
                    .appFont(.lg)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // "Info required" pill
                if requiresIC {
                    InfoRequiredPillView(
                        isSelected: isSelected,
                        accessibilityId: "pay-info-required-badge"
                    )
                }
            }
            .padding(Spacing._5)
            .background(isSelected ? AppColors.foregroundAccentPrimary10Solid : AppColors.foregroundPrimary)
            .cornerRadius(AppRadius._4)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius._4)
                    .stroke(isSelected ? AppColors.borderAccentPrimary : Color.clear, lineWidth: 1)
            )
        }
        .accessibilityIdentifier(accessibilityId)
        .accessibilityLabel(option.amount.display.networkName ?? "unknown")
        .accessibilityElement(children: .contain)
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
