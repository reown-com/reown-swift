import SwiftUI

struct PaymentView: View {
    @EnvironmentObject var presenter: PaymentPresenter
    
    var body: some View {
        VStack(spacing: 20) {
            if presenter.isLoading {
                ProgressView()
            } else if presenter.showSuccess {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    
                    Text("Payment Successful!")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Button("Done") {
                        presenter.dismiss()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            } else if let error = presenter.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.red)
                    
                    Text("Payment Failed")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    ScrollView {
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxHeight: 200)
                    
                    HStack(spacing: 16) {
                        Button("Dismiss") {
                            presenter.dismiss()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        
                        Button("Retry") {
                            presenter.clearError()
                            Task {
                                await presenter.pay()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            } else if let info = presenter.paymentInfo {
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
            } else {
                Text("Loading...")
            }
        }
        .padding()
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

