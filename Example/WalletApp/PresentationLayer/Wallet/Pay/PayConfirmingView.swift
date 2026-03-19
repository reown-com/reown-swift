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

            // Loading text
            Text(presenter.loadingMessage)
                .appFont(.h6)
                .foregroundColor(AppColors.textPrimary)

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
