import SwiftUI

struct PaySuccessView: View {
    @EnvironmentObject var presenter: PayPresenter
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40)
            
            // Pay logo
            HStack(spacing: 6) {
                Image("reown_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text("Pay")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
                .frame(height: 32)
            
            // Checkmark circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.4))
            }
            
            Spacer()
                .frame(height: 24)
            
            // Success text
            Text("Payment successful")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
                .frame(height: 12)
            
            // Amount
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(formattedAmount)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
                
                Text(assetSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
                .frame(height: 12)
            
            // Subtitle
            Text("View all details in your wallet.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
                .frame(height: 40)
            
            // Done button
            Button(action: {
                presenter.dismiss()
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.4))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .padding(.vertical, 16)
            }
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 20)
            
            Spacer()
                .frame(height: 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.7, blue: 0.4),
                    Color(red: 0.15, green: 0.6, blue: 0.35)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(34)
        .padding(.horizontal, 10)
    }
    
    private var formattedAmount: String {
        guard let option = presenter.selectedOption else { return "0.00" }
        let display = option.amount.display
        let value = Double(option.amount.value) ?? 0
        let decimals = display.decimals
        let amount = value / pow(10, Double(decimals))
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }
    
    private var assetSymbol: String {
        presenter.selectedOption?.amount.display.assetSymbol ?? ""
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
