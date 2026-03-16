import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsPresenter
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HeaderView(
                    onScan: { viewModel.scanHandler.show() }
                )

                ScrollView {
                    VStack(spacing: Spacing._2) {

                        SettingsCardView.toggle(
                            "Dark mode",
                            isOn: Binding(
                                get: { viewModel.themeManager.isDarkMode },
                                set: { viewModel.themeManager.isDarkMode = $0 }
                            )
                        )

                        SettingsCardView.navigation("Secret Keys & Phrases") {
                            coordinator.settingsPath.append(SettingsDestination.secretPhrase)
                        }

                        SettingsCardView.navigation("Import Wallet") {
                            viewModel.importWalletPressed()
                        }

                        SettingsCardView.navigation("React-App Browser") {
                            coordinator.settingsPath.append(SettingsDestination.browser)
                        }

                        SettingsCardView.externalLink("Report a Bug") {
                            if let url = URL(string: "https://github.com/reown-com/reown-swift/issues") {
                                UIApplication.shared.open(url)
                            }
                        }

                        sectionHeader(title: "Device")

                        SettingsCardView.info("Client ID", value: truncated(viewModel.clientId)) {
                            UIPasteboard.general.string = viewModel.clientId
                            AlertPresenter.present(message: "Client ID copied", type: .success)
                        }

                        SettingsCardView.info("App Version", value: viewModel.appVersion)
                    }
                    .padding(.horizontal, Spacing._5)
                    .padding(.top, Spacing._3)
                    .padding(.bottom, Spacing._6)
                }
            }
        }
        .scanOptionsSheet(
            isPresented: $viewModel.scanHandler.showScanOptions,
            onScanQR: { viewModel.scanHandler.scanQR() },
            onPasteURL: { viewModel.scanHandler.pasteURL() }
        )
        .sheet(isPresented: $viewModel.showImportWallet) {
            ImportWalletView()
                .environmentObject(viewModel.makeImportWalletPresenter())
                .presentationDetents([.medium, .large])
        }
        .navigationBarHidden(true)
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(AppColors.textSecondary)
                .appFont(.md, weight: .medium)
            Spacer()
        }
        .padding(.top, Spacing._4)
        .padding(.bottom, Spacing._1)
    }

    private func truncated(_ value: String) -> String {
        guard value.count > 20 else { return value }
        return String(value.prefix(10)) + "..." + String(value.suffix(6))
    }
}
