import SwiftUI

struct PayConfirmingView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        PayModalContainer {
            Spacer()
                .frame(height: Spacing._11) // 48px top padding

            // Animated loader
            WalletConnectLoadingView(size: 120)

            Spacer()
                .frame(height: Spacing._4)

            // Loading copy — title + optional subtitle. Cross-fades whenever
            // either field changes (e.g. "Setting up USDC…" → "Finalizing…").
            VStack(spacing: Spacing._2) { // 8px between title and subtitle
                Text(presenter.loadingMessage.title)
                    .appFont(.h6)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("pay-loading-message")

                if let subtitle = presenter.loadingMessage.subtitle {
                    Text(subtitle)
                        .appFont(.lg)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("pay-loading-message-subtitle")
                }
            }
            .padding(.horizontal, Spacing._5)
            .id(presenter.loadingMessage)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .top))
                )
            )
            .animation(.easeInOut(duration: 0.25), value: presenter.loadingMessage)

            Spacer()
                .frame(height: Spacing._7) // 28px + 20px container padding = 48px total
        }
    }
}

#if DEBUG
struct PayConfirmingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayConfirmingView()
        }
    }
}
#endif
