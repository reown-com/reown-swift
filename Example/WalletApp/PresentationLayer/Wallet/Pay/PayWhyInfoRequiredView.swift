import SwiftUI

struct PayWhyInfoRequiredView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        PayModalContainer {
            // Header: back arrow (left) + X close (right)
            PayHeaderBar(
                showBack: true,
                backAction: { presenter.goBack() },
                closeAction: { presenter.dismiss() }
            )

            Spacer()
                .frame(height: Spacing._7)

            // Title
            Text("Why do we collect personal details?")
                .appFont(.h6)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, Spacing._2)

            // Description
            Text("To meet compliance requirements, some basic information is collected from WalletConnect Pay users.\n\nThis is typically a one-time step\u{2014}if you use the same wallet on this network again, you won\u{2019}t need to provide the info again, unless your information changes.")
                .appFont(.lg)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(minHeight: Spacing._7, maxHeight: Spacing._7)

            // "Got it!" button
            PayPrimaryButton(
                title: "Got it!",
                action: { presenter.goBack() }
            )
        }
    }
}

#if DEBUG
struct PayWhyInfoRequiredView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayWhyInfoRequiredView()
        }
    }
}
#endif
