import SwiftUI

struct HeaderView: View {
    let onScan: () -> Void

    var body: some View {
        HStack {
            // WalletConnect logo in accent circle
            ZStack {
                Circle()
                    .fill(AppColors.backgroundAccentPrimary)
                    .frame(width: 38, height: 38)

                Image("wc-brandmark")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AppColors.white)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 18)
            }

            Spacer()

            // Scan button
            Button(action: onScan) {
                Image("barcode-icon")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(AppColors.textInvert)
                    .frame(width: 38, height: 38)
                    .background(AppColors.backgroundInvert)
                    .cornerRadius(CGFloat(AppRadius._3))
            }
            .accessibilityIdentifier("headerScan")
        }
        .padding(.horizontal, Spacing._5)
        .padding(.bottom, Spacing._2)
    }
}
