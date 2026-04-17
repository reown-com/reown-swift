import SwiftUI

struct ScannerOptionsView: View {
    let onScanQR: () -> Void
    let onPasteURL: () -> Void
    let onClose: () -> Void
    @ObservedObject var scanHandler: ScanOptionsHandler

    var body: some View {
        VStack(spacing: Spacing._5) {
            ModalHeaderBar(closeAction: onClose)

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

                #if ENABLE_TEST_MODE
                // Test mode: visible text input for Maestro E2E tests
                VStack(spacing: 8) {
                    TextField("Enter URL", text: $scanHandler.testModeUrl)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier("input-paste-url")

                    Button(action: { scanHandler.submitTestUrl() }) {
                        Text("Submit URL")
                            .appFont(.lg)
                            .foregroundColor(AppColors.textInvert)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColors.backgroundInvert)
                            .cornerRadius(Spacing._3)
                    }
                    .accessibilityIdentifier("button-submit-url")
                }
                .padding(.top, 8)
                #endif
            }
        }
        .padding(.horizontal, Spacing._5)
        .ignoresSafeArea()
        .background(AppColors.backgroundPrimary)
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

// MARK: - Scan Options Sheet Modifier

extension View {
    func scanOptionsSheet(
        isPresented: Binding<Bool>,
        scanHandler: ScanOptionsHandler,
        onScanQR: @escaping () -> Void,
        onPasteURL: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            ScannerOptionsView(
                onScanQR: onScanQR,
                onPasteURL: onPasteURL,
                onClose: { isPresented.wrappedValue = false },
                scanHandler: scanHandler
            )
            .ignoresSafeArea()
            .presentationDragIndicator(.hidden)
            #if ENABLE_TEST_MODE
            .presentationDetents([.height(400)])
            #else
            .presentationDetents([.height(258)])
            #endif
            .sheetBackground()
        }
    }
}
