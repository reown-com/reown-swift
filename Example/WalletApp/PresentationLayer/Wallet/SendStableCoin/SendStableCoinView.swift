import SwiftUI
import AsyncButton

// MARK: - Keyboard-Dismiss Modifier

/// A view modifier that places a full-screen clear layer behind `content`
/// so that tapping anywhere outside of a TextField dismisses the keyboard.
struct HideKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // 1) A full-screen background that's tappable
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            // 2) The actual content on top
            content
        }
    }
}

/// A convenience extension that applies HideKeyboardOnTapModifier
extension View {
    func hideKeyboardOnTap() -> some View {
        self.modifier(HideKeyboardOnTapModifier())
    }
}

// MARK: - Main View

struct SendStableCoinView: View {
    @ObservedObject var presenter: SendStableCoinPresenter

    /// Controls whether the network selection dialog is shown
    @State private var showNetworkPicker = false

    /// Tracks whether the amount TextField is currently focused
    @FocusState private var amountFieldIsFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // 1) "My Address" section
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Address")
                            .foregroundColor(.gray)
                        // Show the real address from importAccount
                        Text(presenter.importAccount.account.address)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity) // Ensures full width
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)

            // 2) Balance section (Combined on top, then USDC & USDT)
            VStack(spacing: 8) {
                // Combined balance
                HStack {
                    Text("Balance")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(presenter.combinedBalance)
                        .font(.system(.body, design: .monospaced))
                }
                Divider()

                // USDC row
                HStack {
                    Image("usdc") // Replace with your USDC asset name
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("USD Coin")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(presenter.usdcBalance) USDC")
                        .font(.system(.body, design: .monospaced))
                }

                // USDT row
                HStack {
                    Image("usdt") // Replace with your USDT asset name
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Tether USD")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(presenter.usdtBalance) USDT")
                        .font(.system(.body, design: .monospaced))
                }
                
                // USDS (DAI) row
                HStack {
                    Image("usdt") // Reusing USDT icon as a placeholder, can be replaced with DAI icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("DAI Stablecoin")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(presenter.usdsBalance) DAI")
                        .font(.system(.body, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)

            // 3) Transaction card
            VStack(spacing: 20) {
                Text("Transaction")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Stable coin picker: USDC, USDT, or USDS
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coin")
                        .foregroundColor(.gray)
                    Picker("Stablecoin", selection: $presenter.stableCoinChoice) {
                        Text("USDC").tag(StableCoinChoice.usdc)
                        Text("USDT").tag(StableCoinChoice.usdt)
                        Text("USDS").tag(StableCoinChoice.usds)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

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
                        // The amount TextField, with decimal keyboard
                        TextField("0.00", text: $presenter.amount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($amountFieldIsFocused)
                            // Add a toolbar with "Done" to dismiss the keyboard
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        // Unfocus the text field => dismiss keyboard
                                        amountFieldIsFocused = false
                                    }
                                }
                            }

                        Button {
                            showNetworkPicker = true
                        } label: {
                            Text(presenter.selectedNetwork.rawValue)
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        // Confirmation dialog for picking network
                        .confirmationDialog(
                            "Select Network",
                            isPresented: $showNetworkPicker,
                            titleVisibility: .visible
                        ) {
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
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)

            Spacer()

            // 4) "Send" button
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
        .hideKeyboardOnTap() // Tap anywhere to dismiss keyboard
        // Present success screen when transaction completes
        .sheet(isPresented: $presenter.transactionCompleted) {
            SendStableCoinCompletedView(presenter: presenter)
        }
    }
}

// MARK: - "Transaction Completed" Screen

struct SendStableCoinCompletedView: View {
    @ObservedObject var presenter: SendStableCoinPresenter

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer()

                Image("tada")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text("Transaction Completed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("You've successfully sent your stablecoin transaction.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

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
                Button(action: {
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
