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
                    Text("\(presenter.payingAmount, specifier: "%.2f") USDC")
                        .font(.system(.body, design: .monospaced))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Source of funds
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source of funds")
                        .foregroundColor(.gray)

                    // Iterate over funding sources
                    ForEach(presenter.fundingFrom, id: \.chainId) { funding in
                        HStack {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .foregroundColor(.gray)
                            VStack(alignment: .leading) {
                                Text("\(funding.amount) \(funding.symbol)")
                                    .font(.system(.body, design: .monospaced))
                                Text("from \(presenter.network(for: funding.chainId))")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                }

                // App and Network
                VStack(spacing: 12) {
                    HStack {
                        Text("App")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(presenter.appURL)
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Network")
                            .foregroundColor(.gray)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                            Text(presenter.networkName)
                        }
                    }
                }

                // Estimated Fees Section
                VStack(spacing: 12) {
                    HStack {
                        Text("Estimated Fees")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("$\(presenter.estimatedFees, specifier: "%.2f")")
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("Bridge")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$\(presenter.bridgeFee, specifier: "%.2f")")
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Purchase")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$\(presenter.purchaseFee, specifier: "%.2f")")
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Execution")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(presenter.executionSpeed)
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
                    presenter.approveTransactions()
                }) {
                    Text("Approve")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }

                Button(action: {
                    Task(priority: .userInitiated) {
                        try await presenter.rejectTransactions()
                    }
                }) {
                    Text("Reject")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
}
