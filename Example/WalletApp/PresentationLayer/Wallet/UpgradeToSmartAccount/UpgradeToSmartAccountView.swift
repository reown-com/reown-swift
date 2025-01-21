import SwiftUI
import AsyncButton

struct UpgradeToSmartAccountView: View {
    @ObservedObject var presenter: UpgradeToSmartAccountPresenter

    var body: some View {
        VStack(spacing: 0) {
            // Top Header
            HStack {
                Text("Upgrade to Smart Account")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    presenter.cancel()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }
            .padding()

            // Explanation text
            Text("To upgrade your account, you need to sign a transaction with your wallet.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            // Features card
            VStack(alignment: .leading, spacing: 12) {
                Text("Get access to advanced features")
                    .font(.body).bold()

                Label("Sponsored Transactions", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("Bundle Transactions", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)

                Text("and more in the future...")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Wallet/Network/Fees card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Wallet")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(presenter.importAccount.account.address) 
                        .font(.system(.body, design: .monospaced))
                }
                Divider()
                HStack {
                    Text("Network")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(presenter.selectedNetwork.rawValue)
                        .foregroundColor(.blue)
                }
                Divider()
                HStack {
                    Text("Fees")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("FREE")
                        .foregroundColor(.green)
                }
                Divider()
                HStack {
                    Text("Sponsored By")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("reown") // Example sponsor
                }
            }
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Spacer()

            // Bottom actions row
            HStack {
                Button(action: {
                    presenter.cancel()
                }) {
                    Text("Cancel")
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(.systemGray3).opacity(0.3))
                .cornerRadius(12)

                Spacer()

                AsyncButton(
                    options: [
                        .showProgressViewOnLoading,
                        .disableButtonOnLoading,
                        .showAlertOnError,
                        .enableNotificationFeedback
                    ]
                ) {
                    try await presenter.signAndUpgrade()
                } label: {
                    Text("Sign & Upgrade")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all)) // Example dark background
    }
}
