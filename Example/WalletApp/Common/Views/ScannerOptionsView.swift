import SwiftUI

struct ScannerOptionsView: View {
    let onScanQR: () -> Void
    let onPasteURL: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .onTapGesture { onClose() }

            VStack {
                Spacer()

                ModalContainer {
                    ModalHeaderBar(closeAction: onClose)
                        .padding(.bottom, Spacing._5)

                    VStack(spacing: 8) {
                        optionButton(
                            title: "Scan QR code",
                            icon: {
                                Image("barcode-icon")
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(AppColors.textPrimary)
                            },
                            action: onScanQR
                        )

                        optionButton(
                            title: "Paste a URL",
                            icon: {
                                CopyIconShape()
                                    .fill(AppColors.textPrimary)
                                    .frame(width: 20, height: 20)
                            },
                            action: onPasteURL
                        )
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    private func optionButton<Icon: View>(
        title: String,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .appFont(.lg)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                icon()
            }
            .padding(.horizontal, Spacing._6)
            .frame(height: 76)
            .background(AppColors.foregroundPrimary)
            .cornerRadius(Spacing._5)
        }
    }
}
