import SwiftUI

struct SecretPhraseView: View {
    @EnvironmentObject var viewModel: SecretPhrasePresenter

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: Spacing._3) {
                    warningBanner()

                    Group {
                        header(title: "Account")
                        row(title: "CAIP-10", subtitle: viewModel.evmAccount)
                        row(title: "Private key", subtitle: viewModel.evmPrivateKey)

                        header(title: "Stacks")
                        row(title: "Stacks Mnemonic", subtitle: viewModel.stacksMnemonic)
                        row(title: "Stacks Mainnet Address", subtitle: viewModel.stacksMainnetAddress)
                        row(title: "Stacks Testnet Address", subtitle: viewModel.stacksTestnetAddress)

                        header(title: "Solana")
                        row(title: "Solana Address", subtitle: viewModel.solanaAddress)
                        row(title: "Solana Private Key", subtitle: viewModel.solanaPrivateKey)
                    }

                    Group {
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
                }
                .padding(.horizontal, Spacing._5)
                .padding(.bottom, Spacing._6)
            }
        }
        .navigationTitle("Secret Keys & Phrases")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func warningBanner() -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.textWarning)
            Text("Keys are for development purposes only")
                .appFont(.md)
                .foregroundColor(AppColors.textWarning)
            Spacer()
        }
        .padding(Spacing._4)
        .background(AppColors.backgroundWarning)
        .cornerRadius(AppRadius._3)
        .padding(.top, Spacing._3)
    }

    private func header(title: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(AppColors.textPrimary)
                .appFont(.xl, weight: .medium)
                .padding(.vertical, Spacing._05)
            Spacer()
        }
    }

    private func row(title: String, subtitle: String) -> some View {
        Button {
            UIPasteboard.general.string = subtitle
            WalletToast.present(message: "\(title) copied", type: .success)
        } label: {
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
}
