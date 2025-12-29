import SwiftUI
import WalletConnectPay

struct PayIntroView: View {
    @EnvironmentObject var presenter: PayPresenter
    
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
            
            if presenter.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading payment details...")
                        .foregroundColor(.grey50)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .frame(height: 300)
            } else if let info = presenter.paymentInfo {
                // Merchant icon
                if let iconUrl = info.merchant.iconUrl {
                    AsyncImage(url: URL(string: iconUrl)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            merchantPlaceholder(name: info.merchant.name)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
                    .padding(.top, 16)
                } else {
                    merchantPlaceholder(name: info.merchant.name)
                        .frame(width: 64, height: 64)
                        .padding(.top, 16)
                }
                
                // Payment title
                HStack(spacing: 6) {
                    Text("Pay \(info.formattedAmount) to \(info.merchant.name)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.grey8)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .padding(.top, 16)
                
                // Steps
                VStack(spacing: 16) {
                    // Step 1: Provide information
                    PayStepRow(
                        stepNumber: 1,
                        isCompleted: false,
                        title: "Provide information",
                        subtitle: "A quick one-time check required for regulated payments.",
                        estimatedTime: "~2min"
                    )
                    
                    // Step 2: Confirm payment
                    PayStepRow(
                        stepNumber: 2,
                        isCompleted: false,
                        title: "Confirm payment",
                        subtitle: "Review the details and approve the payment."
                    )
                }
                .padding(.top, 24)
                .padding(.horizontal, 4)
                
                // Let's start button
                Button(action: {
                    presenter.startFlow()
                }) {
                    Text("Let's start")
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
                .padding(.top, 24)
            } else {
                // No payment info available
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.grey50)
                    Text("Unable to load payment details")
                        .foregroundColor(.grey50)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .frame(height: 300)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
    
    private func merchantPlaceholder(name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.grey95)
            Text(String(name.prefix(1)))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.grey8)
        }
    }
}

struct PayStepRow: View {
    let stepNumber: Int
    let isCompleted: Bool
    let title: String
    let subtitle: String
    var estimatedTime: String? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step indicator
            ZStack {
                Circle()
                    .stroke(isCompleted ? Color.foregroundPositive : Color.grey95, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.foregroundPositive)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.grey8)
                    
                    Spacer()
                    
                    if let time = estimatedTime {
                        Text(time)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.grey50)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.grey95.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.grey50)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
struct PayIntroView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayIntroView()
        }
    }
}
#endif
