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

            // Loading text — fades + slides when the message changes between steps
            // (e.g. "Setting up USDC…" → "Finalizing your payment…").
            Text(presenter.loadingMessage)
                .appFont(.h6)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing._5)
                .id(presenter.loadingMessage)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    )
                )
                .animation(.easeInOut(duration: 0.25), value: presenter.loadingMessage)
                .accessibilityIdentifier("pay-loading-message")

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
