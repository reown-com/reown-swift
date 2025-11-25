import SwiftUI

struct PaymentView: View {
    @EnvironmentObject var presenter: PaymentPresenter
    
    var body: some View {
        VStack(spacing: 20) {
            if presenter.isLoading {
                ProgressView()
            } else if let info = presenter.paymentInfo {
                if presenter.showSuccess {
                    VStack {
                        Text("Success!")
                            .font(.title)
                            .foregroundColor(.green)
                        Button("OK") {
                            presenter.dismiss()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Payment Request")
                            .font(.headline)
                        
                        Text("Amount: \(formatAmount(info.amount)) USDC")
                            .font(.largeTitle)
                        
                        Text("Reference: \(info.referenceId)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            Task {
                                await presenter.pay()
                            }
                        }) {
                            Text("Pay")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
            } else if let error = presenter.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                Button("Retry") {
                    Task {
                        await presenter.loadPaymentInfo()
                    }
                }
            } else {
                Text("Loading...")
            }
        }
        .onAppear {
            Task {
                await presenter.loadPaymentInfo()
            }
        }
    }
    
    func formatAmount(_ amount: Int) -> String {
        let dollars = Double(amount) / 100.0
        return String(format: "%.2f", dollars)
    }
}

