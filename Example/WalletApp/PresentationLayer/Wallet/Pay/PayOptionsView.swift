import SwiftUI
import WalletConnectPay

struct PayOptionsView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        VStack(spacing: 0) {
            // Header: "Why info required?" pill (left) + X close (right)
            HStack {
                if presenter.anyOptionRequiresIC {
                    Button(action: {
                        presenter.showWhyInfoRequiredScreen()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12, weight: .medium))
                            Text("Why info required?")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.grey50)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.grey95.opacity(0.5))
                        .cornerRadius(12)
                    }
                }

                Spacer()

                Button(action: {
                    presenter.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grey50)
                        .frame(width: 30, height: 30)
                        .background(Color.grey95.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if presenter.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading payment details...")
                        .foregroundColor(.grey50)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .frame(height: 300)
            } else if presenter.paymentOptions.isEmpty {
                noPaymentOptionsView
            } else if let info = presenter.paymentInfo {
                // Merchant icon with verified badge
                MerchantHeader(info: info)
                    .padding(.top, 16)

                // Payment options list
                VStack(spacing: 10) {
                    ForEach(presenter.paymentOptions, id: \.id) { option in
                        PaymentOptionCard(
                            option: option,
                            isSelected: presenter.selectedOption?.id == option.id,
                            requiresIC: presenter.anyOptionRequiresIC,
                            onSelect: { presenter.selectOption(option) }
                        )
                    }
                }
                .padding(.top, 20)

                // Primary button
                Button(action: {
                    presenter.continueFromOptions()
                }) {
                    Text(presenter.optionsButtonTitle)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue100, .blue200]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.top, 16)
                .disabled(presenter.selectedOption == nil)
            } else {
                // No payment info available
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.grey50)
                    Text("Unable to load payment details")
                        .foregroundColor(.grey50)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .frame(height: 300)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private var noPaymentOptionsView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.red)
            }
            .padding(.top, 40)

            Text("No payment options available")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.grey8)

            Spacer()
                .frame(height: 20)

            Button(action: {
                presenter.dismiss()
            }) {
                Text("Close")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue100, .blue200]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
            }
        }
        .frame(minHeight: 250)
    }
}

// MARK: - Merchant Header

struct MerchantHeader: View {
    let info: PaymentInfo

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
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
                    .cornerRadius(12)
                } else {
                    merchantPlaceholder(name: info.merchant.name)
                        .frame(width: 64, height: 64)
                }

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .background(Circle().fill(Color.white).frame(width: 16, height: 16))
                    .offset(x: 4, y: 4)
            }

            Text("Pay \(info.formattedAmount) to \(info.merchant.name)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.grey8)
                .padding(.top, 16)
        }
    }

    private func merchantPlaceholder(name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.grey95)
            Text(String(name.prefix(1)))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.grey8)
        }
    }
}

// MARK: - Payment Option Card

struct PaymentOptionCard: View {
    let option: PaymentOption
    let isSelected: Bool
    let requiresIC: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Token icon with network badge
                TokenIconWithNetwork(
                    iconUrl: option.amount.display.iconUrl,
                    networkIconUrl: option.amount.display.networkIconUrl,
                    symbol: option.amount.display.assetSymbol,
                    size: 40
                )

                // Token amount
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.formattedAmount)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.grey8)

                    if let networkName = option.amount.display.networkName {
                        Text("on \(networkName)")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.grey50)
                    }
                }

                Spacer()

                // "Info required" badge
                if requiresIC {
                    Text("Info required")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.grey50)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.grey95.opacity(0.5))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.blue100.opacity(0.08) : Color.grey95.opacity(0.3))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue100 : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Token Icon With Network Badge

struct TokenIconWithNetwork: View {
    let iconUrl: String?
    let networkIconUrl: String?
    let symbol: String
    let size: CGFloat

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
                .frame(width: size * 0.4, height: size * 0.4)
                .clipShape(Circle())
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: size * 0.45, height: size * 0.45)
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
                .fill(Color.grey95)
            Text(String(symbol.prefix(1)))
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.grey50)
        }
        .frame(width: size, height: size)
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
