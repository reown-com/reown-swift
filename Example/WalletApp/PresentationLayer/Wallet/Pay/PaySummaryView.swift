import SwiftUI
import WalletConnectPay

struct PaySummaryView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        VStack(spacing: 0) {
            // Header: X close (right only)
            HStack {
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

            if let info = presenter.paymentInfo {
                // Merchant header
                MerchantHeader(info: info)
                    .padding(.top, 16)

                // "Pay with" row
                if let option = presenter.selectedOption {
                    HStack {
                        Text("Pay with")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.grey50)

                        Spacer()

                        HStack(spacing: 8) {
                            Text(option.formattedAmount)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.grey8)

                            TokenIconWithNetwork(
                                iconUrl: option.amount.display.iconUrl,
                                networkIconUrl: option.amount.display.networkIconUrl,
                                symbol: option.amount.display.assetSymbol,
                                size: 24
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.grey95.opacity(0.3))
                    .cornerRadius(16)
                    .padding(.top, 24)
                }

                Spacer()
                    .frame(minHeight: 20, maxHeight: 40)

                // Pay button
                Button(action: {
                    presenter.confirmPayment()
                }) {
                    Text("Pay \(info.formattedAmount)")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .padding(.vertical, 16)
                }
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
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
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
