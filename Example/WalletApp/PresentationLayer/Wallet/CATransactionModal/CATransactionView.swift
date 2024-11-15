import SwiftUI

struct CATransactionView: View {
    @EnvironmentObject var presenter: CATransactionPresenter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Review Transaction")
                .font(.headline)
                .padding(.top)

            VStack(spacing: 20) {
                // Paying Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paying")
                        .foregroundColor(.gray)
                    Text("10.00 USDC")
                        .font(.system(.body, design: .monospaced))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Source of funds
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source of funds")
                        .foregroundColor(.gray)

                    // Balance Row
                    HStack {
                        Image(systemName: "creditcard.circle.fill")
                            .foregroundColor(.blue)
                        Text("Balance")
                        Spacer()
                        Text("5.00 USDC")
                            .font(.system(.body, design: .monospaced))
                    }

                    // Bridging Row
                    HStack {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .foregroundColor(.gray)
                        Text("Bridging")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("5.00 USDC")
                                .font(.system(.body, design: .monospaced))
                            Text("from Optimism")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                }

                // App and Network
                VStack(spacing: 12) {
                    HStack {
                        Text("App")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("https://sampleapp.com")
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Network")
                            .foregroundColor(.gray)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                            Text("Arbitrum")
                        }
                    }
                }

                // Estimated Fees Section
                VStack(spacing: 12) {
                    HStack {
                        Text("Estimated Fees")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("$4.34")
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("Bridge")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$3.00")
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Purchase")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$1.34")
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Execution")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("Fast (~20 sec)")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .padding(.leading)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()

            // Action Buttons
            VStack(spacing: 12) {
                Button(action: {
                    // Buy action
                }) {
                    Text("Buy")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
}

