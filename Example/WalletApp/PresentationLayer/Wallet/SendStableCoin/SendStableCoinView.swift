import SwiftUI
import AsyncButton

struct SendStableCoinView: View {
    @ObservedObject var presenter: SendStableCoinPresenter

    @State private var showNetworkPicker = false

    // Example placeholders; adjust as needed
    let myAddressShort = "0x742...f44e"
    let balanceAmount = 1000.03
    let feesApprox = "~$0.17"

    var body: some View {
        VStack(spacing: 24) {

            // Top row: My Address + Upgrade Button
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Address")
                            .foregroundColor(.gray)
                        Text(myAddressShort)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)

            // Balance section
            VStack(spacing: 8) {
                HStack {
                    Text("Balance")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("$1,000")
                        .font(.system(.body, design: .monospaced))
                }
                // USDC row
                HStack {
                    Image("usdc") // Replace with your USDC asset image name
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("USD Coin")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(String(format: "%.2f", balanceAmount)) USDC")
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)

            // Transaction card
            VStack(spacing: 20) {
                Text("Transaction 1")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Recipient
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient")
                        .foregroundColor(.gray)
                    TextField("0x1234... or ENS", text: $presenter.recipient)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }

                // Amount + network
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount to send")
                        .foregroundColor(.gray)

                    HStack {
                        TextField("0.00", text: $presenter.amount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        Button(action: {
                            showNetworkPicker = true
                        }) {
                            Text(presenter.selectedNetwork.rawValue)
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .confirmationDialog("Select Network",
                                            isPresented: $showNetworkPicker,
                                            titleVisibility: .visible) {
                            Button(L2.Arbitrium.rawValue) {
                                presenter.set(network: .Arbitrium)
                            }
                            Button(L2.Base.rawValue) {
                                presenter.set(network: .Base)
                            }
                            Button(L2.Optimism.rawValue) {
                                presenter.set(network: .Optimism)
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
            }
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)

            Spacer()

            VStack(spacing: 12) {
                AsyncButton(
                    options: [
                        .showProgressViewOnLoading,
                        .disableButtonOnLoading,
                        .showAlertOnError,
                        .enableNotificationFeedback
                    ]
                ) {
                    try await presenter.send()
                } label: {
                    Text("Send")
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
            .padding()
        }
        .padding()
        // Present success screen
        .sheet(isPresented: $presenter.transactionCompleted) {
            SendStableCoinCompletedView(presenter: presenter)
        }
    }
}


struct SendStableCoinCompletedView: View {
    @ObservedObject var presenter: SendStableCoinPresenter

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer()

                // "Tada" or confetti image at top
                Image("tada")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                // Title
                Text("Transaction Completed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Subtitle or descriptive text
                Text("You’ve successfully sent your stablecoin transaction.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Show the transaction hash if present
                if let txHash = presenter.transactionResult, !txHash.isEmpty {
                    VStack(spacing: 4) {
                        Text("Transaction Hash")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        Text(txHash)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()

                // Done button to dismiss
                Button(action: {
                    // Setting transactionCompleted = false hides this sheet
                    presenter.transactionCompleted = false
                }) {
                    Text("Done")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding()
        }
    }
}
