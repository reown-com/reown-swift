import SwiftUI

/// SwiftUI view that binds directly to the presenter's `recipient` and `amount`
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
                    Spacer()
                    Button(action: {
                        presenter.upgradeToSmartAccount()
                    }) {
                        Text("Upgrade to Smart Account")
                            .foregroundColor(.blue)
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

                        // Display the enum's raw value instead of a String
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
                            Button(L2.Sepolia.rawValue) {
                                presenter.set(network: .Sepolia)
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }

                // Add Transaction button (if you need multiple transaction flows)
                Button(action: {
                    // TODO: handle adding additional transactions
                }) {
                    Label("Add Transaction", systemImage: "plus")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)

            // Fees row
            HStack {
                Text("Fees")
                    .foregroundColor(.gray)
                Spacer()
                Text(feesApprox)
                    .font(.system(.body, design: .monospaced))
            }
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)

            Spacer()

            // Send button
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        do {
                            // Now we call presenter's send(), no params needed
                            try await presenter.send()
                        } catch {
                            // If send() throws, show an alert or handle error
                            AlertPresenter.present(
                                message: error.localizedDescription,
                                type: .error
                            )
                        }
                    }
                }) {
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
    }
}
