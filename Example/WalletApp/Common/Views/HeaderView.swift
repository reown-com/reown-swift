import SwiftUI

struct HeaderView: View {
    let onScan: () -> Void
    var onNfc: (() -> Void)?
    var isNfcAvailable: Bool = false

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

            HStack(spacing: Spacing._2) {
                // NFC button
                if isNfcAvailable, let onNfc {
                    Button(action: onNfc) {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(AppColors.backgroundPrimary)
                            .cornerRadius(CGFloat(AppRadius._3))
                            .overlay(
                                RoundedRectangle(cornerRadius: CGFloat(AppRadius._3))
                                    .stroke(AppColors.foregroundTertiary, lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("headerNfc")
                }

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
        }
        .padding(.horizontal, Spacing._5)
        .padding(.bottom, Spacing._2)
    }
}
