import SwiftUI
import AsyncButton

struct CATransactionView: View {
    @EnvironmentObject var presenter: CATransactionPresenter
    @Environment(\.dismiss) private var dismiss
    @State private var viewScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if presenter.transactionCompleted {
                TransactionCompletedView()
                    .scaleEffect(viewScale) // Apply the renamed property here
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            viewScale = 1.0 // Reset scaling for the new view
                        }
                    }
            } else {
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
                            Text("$TODO")
                            //                    Text("\(presenter.payingAmount, specifier: "%.2f") USDC")
                                .font(.system(.body, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Source of funds
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Source of funds")
                                .foregroundColor(.gray)

                            ForEach(presenter.fundingFrom, id: \.chainId) { funding in
                                HStack {
                                    Spacer() // Push content to the right
                                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                                        .foregroundColor(.gray)
                                    VStack(alignment: .leading) {
                                        // Use the presenter for conversion
                                        Text("\(presenter.hexAmountToDenominatedUSDC(funding.amount)) \(funding.symbol)")
                                            .font(.system(.body, design: .monospaced))
                                        Text("from \(presenter.network(for: funding.chainId))")
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing) // Ensure the entire HStack aligns to the trailing edge
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
                                Text("\(presenter.estimatedFees)")
                                    .font(.system(.body, design: .monospaced))
                            }

                            VStack(spacing: 8) {
                                HStack {
                                    Text("Bridge")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("$TODO")
                                    //                            Text("$\(presenter.bridgeFee, specifier: "%.2f")")
                                        .font(.system(.body, design: .monospaced))
                                }

                                HStack {
                                    Text("Purchase")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    //                            Text("$\(presenter.purchaseFee, specifier: "%.2f")")
                                    Text("$TODO")
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
//                        AsyncButton(
//                            options: [
//                                .showProgressViewOnLoading,
//                                .disableButtonOnLoading,
//                                .showAlertOnError,
//                                .enableNotificationFeedback
//                            ]
//                        ) {
//                            try await presenter.testAsyncSuccess()
//                        } label: {
//                            Text("Test Success")
//                                .fontWeight(.semibold)
//                                .foregroundColor(.white)
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color.green)
//                                .cornerRadius(12)
//                        }
//
//                        // Error test button
//                        AsyncButton(
//                            options: [
//                                .showProgressViewOnLoading,
//                                .disableButtonOnLoading,
//                                .showAlertOnError,
//                                .enableNotificationFeedback
//                            ]
//                        ) {
//                            try await presenter.testAsyncError()
//                        } label: {
//                            Text("Test Error")
//                                .fontWeight(.semibold)
//                                .foregroundColor(.white)
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color.red)
//                                .cornerRadius(12)
//                        }

                        // Original Approve button
                        AsyncButton(
                            options: [
                                .showProgressViewOnLoading,
                                .disableButtonOnLoading,
                                .showAlertOnError,
                                .enableNotificationFeedback
                            ]
                        ) {
                            try await presenter.approveTransactions()
                        } label: {
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
    }
}


struct TransactionCompletedView: View {
    @EnvironmentObject var presenter: CATransactionPresenter

    var body: some View {
        VStack(spacing: 32) {
            Text("Transaction Completed")
                .font(.title2)
                .fontWeight(.semibold)

            // Original tada image in blue-purple gradient circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image("tada")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }

            Text("You successfully sent USDC!")
                .font(.title3)
                .foregroundColor(.gray)

            // Transaction details
            VStack(spacing: 24) {
                HStack {
                    Text("Payed")
                        .foregroundColor(.gray)
                    Spacer()
                        Text("X USDC")
                            .font(.system(.body, design: .monospaced))
                        Text("on ")
                        Text("\(presenter.networkName)")
                            .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("Bridged")
                        .foregroundColor(.gray)
                    Spacer()
                    ForEach(presenter.fundingFrom, id: \.chainId) { funding in
                        Text("\(presenter.hexAmountToDenominatedUSDC(funding.amount)) \(funding.symbol)")
                            .font(.system(.body, design: .monospaced))
                        Text("from ")
                        Text("\(presenter.network(for: funding.chainId))")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)

            // View on Explorer button
            Button(action: {
                presenter.onViewOnExplorer()
            }) {
                HStack {
                    Text("View on Explorer")
                    Image(systemName: "arrow.up.forward")
                        .font(.footnote)
                }
                .foregroundColor(.gray)
            }

            Spacer()

            // Back to App button
            Button(action: {
                presenter.dismiss()
            }) {
                Text("Back to App")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
}
