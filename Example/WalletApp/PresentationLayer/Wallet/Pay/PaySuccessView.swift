import SwiftUI

struct PaySuccessView: View {
    @EnvironmentObject var presenter: PayPresenter
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: {
                    presenter.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grey50)
                        .frame(width: 30, height: 30)
                        .background(Color.grey95.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Spacer()
                .frame(height: 24)
            
            // Animated checkmark circle
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.green)
            }
            .scaleEffect(checkmarkScale)
            .opacity(checkmarkOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    checkmarkScale = 1.0
                    checkmarkOpacity = 1.0
                }
            }
            
            Spacer()
                .frame(height: 20)
            
            // Success message with merchant name
            Text("You've paid \(formattedAmount) to \(merchantName)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.grey8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
                .frame(minHeight: 30, maxHeight: 50)
            
            // Got it button
            Button(action: {
                presenter.dismiss()
            }) {
                Text("Got it!")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue100, .blue200]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
    
    /// Merchant name from payment info
    /// This comes from `paymentOptionsResponse.info.merchant.name` which is returned by the Pay API
    private var merchantName: String {
        presenter.paymentInfo?.merchant.name ?? "Merchant"
    }
    
    /// Formatted payment amount (e.g., "$32,900")
    private var formattedAmount: String {
        presenter.paymentInfo?.formattedAmount ?? "$0.00"
    }
}

#if DEBUG
struct PaySuccessView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PaySuccessView()
        }
    }
}
#endif
