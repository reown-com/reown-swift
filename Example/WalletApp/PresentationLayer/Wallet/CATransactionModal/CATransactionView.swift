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
                    .scaleEffect(viewScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            viewScale = 1.0
                        }
                    }
            } else {
                VStack(spacing: 24) {
                    // Header
                    Text("Review Transaction")
                        .font(.headline)
                        .padding(.top)

                    // FIRST SECTION (Darker background)
                    VStack(spacing: 20) {
                        // Paying Row
                        HStack {
                            Text("Paying")
                                .foregroundColor(.gray)
                            Spacer()
                            // Use the token symbol from presenter
                            Text("\(presenter.hexAmountToDenominatedUSDC(presenter.payingAmount)) \(presenter.payingTokenSymbol)")
                                .font(.system(.body, design: .monospaced))
                        }

                        // Source of Funds Title

                        // Subsection (lighter background) for Source of Funds details
                        VStack(spacing: 4) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Source of funds")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Balance line
                            HStack {
                                Image(presenter.networkName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.gray)
                                Text("Balance")
                                    .foregroundColor(.gray)
                                Spacer()
                                // Use the token symbol from presenter
                                Text("\(presenter.hexAmountToDenominatedUSDC(presenter.balanceAmount)) \(presenter.payingTokenSymbol)")
                                    .font(.system(.body, design: .monospaced))
                            }

                            // Bridging line(s)
                            ForEach(presenter.fundingFrom, id: \.chainId) { funding in
                                HStack {
                                    Image("bridging")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 32, height: 32)
                                    Text("Bridging")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("\(presenter.hexAmountToDenominatedUSDC(funding.amount)) \(funding.symbol)")
                                            .font(.system(.body, design: .monospaced))
                                        HStack{
                                            Text("from \(presenter.network(for: funding.chainId))")
                                                .font(.footnote)
                                                .foregroundColor(.gray)
                                            Image(presenter.network(for: funding.chainId))
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 12, height: 12)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color("grey-subsection"))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color("grey-section"))
                    .cornerRadius(12)

                    // SECOND SECTION (Darker background)
                    VStack(spacing: 20) {
                        // App
                        HStack {
                            Text("App")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(presenter.appURL)
                                .foregroundColor(.blue)
                        }

                        // Network
                        HStack {
                            Text("Network")
                                .foregroundColor(.gray)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(presenter.networkName)
                                    .resizable() // Ensure the image scales
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.blue)
                                Text(presenter.networkName)
                            }
                        }

                        // Estimated Fees Title

                        // Subsection (lighter background) for fees breakdown
                        VStack(spacing: 8) {
                            HStack {
                                Text("Estimated Fees")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(presenter.formattedEstimatedFees)")
                                    .font(.system(.body, design: .monospaced))
                            }

                            
                            HStack {
                                Text("Bridge")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(presenter.formattedBridgeFee)")
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
                        .padding()
                        .background(Color("grey-subsection"))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color("grey-section"))
                    .cornerRadius(12)

                    Spacer()

                    // Action Buttons
                    VStack(spacing: 12) {
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

            Image("tada")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)

            Text("You successfully sent \(presenter.payingTokenSymbol)!")
                .font(.title3)
                .foregroundColor(.gray)

            // Transaction details
            VStack(spacing: 24) {
                HStack {
                    Text("Payed")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(presenter.hexAmountToDenominatedUSDC(presenter.payingAmount)) \(presenter.payingTokenSymbol)")
                        .font(.system(.body, design: .monospaced))
                    Text("on")
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
                        Text("from")
                        Text("\(presenter.network(for: funding.chainId))")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)

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
