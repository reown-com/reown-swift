import SwiftUI
import AsyncButton

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsPresenter
    @State private var copyAlert: Bool = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HeaderView(
                    onScan: { viewModel.onScanOptions() }
                )

                ScrollView {
                    VStack(spacing: Spacing._3) {
                        separator()

                        Group {
                            header(title: "Account")
                            row(title: "CAIP-10", subtitle: viewModel.account)
                            row(title: "Private key", subtitle: viewModel.privateKey)

                            header(title: "Stacks")
                            row(title: "Stacks Mnemonic", subtitle: viewModel.stacksMnemonic)
                            row(title: "Stacks Mainnet Address", subtitle: viewModel.stacksMainnetAddress)
                            row(title: "Stacks Testnet Address", subtitle: viewModel.stacksTestnetAddress)

                            header(title: "Solana")
                            row(title: "Solana Address", subtitle: viewModel.solanaAddress)
                            row(title: "Solana Private Key", subtitle: viewModel.solanaPrivateKey)

                            header(title: "Sui")
                            row(title: "Sui Address", subtitle: viewModel.suiAddress)
                            row(title: "Sui Private Key", subtitle: viewModel.suiPrivateKey)

                            header(title: "TON")
                            row(title: "TON Address", subtitle: viewModel.tonAddress)
                            row(title: "TON Private Key", subtitle: viewModel.tonPrivateKey)

                            header(title: "Tron")
                            row(title: "Tron Address", subtitle: viewModel.tronAddress)
                            row(title: "Tron Private Key", subtitle: viewModel.tronPrivateKey)
                        }
                        .padding(.horizontal, Spacing._5)

                        separator()

                        Group {
                            header(title: "Device")
                            row(title: "Client ID", subtitle: viewModel.clientId)
                        }
                        .padding(.horizontal, Spacing._5)

                        separator()

                        Group {
                            Button {
                                viewModel.browserPressed()
                            } label: {
                                Text("Browser")
                                    .appFont(.lg, weight: .medium)
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(AppColors.foregroundPrimary)
                                    .cornerRadius(CGFloat(AppRadius._3))
                            }

                            AsyncButton {
                                try await viewModel.logoutPressed()
                            } label: {
                                Text("Log out")
                                    .appFont(.lg, weight: .medium)
                                    .foregroundColor(AppColors.textError)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: CGFloat(AppRadius._3))
                                    .stroke(AppColors.borderError, lineWidth: 1)
                            )
                            .padding(.bottom, Spacing._6)
                        }
                        .padding(.horizontal, Spacing._5)
                    }
                }
            }
        }
        .alert("Value copied to clipboard", isPresented: $copyAlert) {
            Button("OK", role: .cancel) { }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.objectWillChange.send()
        }
    }

    func header(title: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(AppColors.textPrimary)
                .appFont(.xl, weight: .medium)
                .padding(.vertical, Spacing._05)
            Spacer()
        }
    }

    func row(title: String, subtitle: String) -> some View {
        return Button(action: {
            UIPasteboard.general.string = subtitle
            copyAlert = true
        }) {
            VStack(alignment: .leading, spacing: Spacing._1) {
                HStack(spacing: Spacing._05) {
                    Text(title)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(AppColors.textPrimary)
                        .appFont(.md, weight: .medium)

                    Image("copy_small")
                        .foregroundColor(AppColors.iconDefault)

                    Spacer()
                }
                .padding(.horizontal, Spacing._3)
                .padding(.top, Spacing._4)

                Text(subtitle)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(AppColors.textSecondary)
                    .appFont(.md)
                    .padding(.horizontal, Spacing._3)
                    .padding(.bottom, Spacing._4)
            }
            .background(
                RoundedRectangle(cornerRadius: CGFloat(AppRadius._3))
                    .fill(AppColors.foregroundPrimary)
            )
        }
        .frame(maxWidth: .infinity)
    }

    func separator() -> some View {
        Rectangle()
            .foregroundColor(AppColors.borderPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .padding(.top, Spacing._2)
    }
}
