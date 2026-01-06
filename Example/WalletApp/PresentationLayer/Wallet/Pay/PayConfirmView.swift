import SwiftUI
import WalletConnectPay

struct PayConfirmView: View {
    @EnvironmentObject var presenter: PayPresenter
    @State private var showOptionPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and close
            HStack {
                Button(action: {
                    presenter.goBack()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grey8)
                }
                
                Spacer()
                
                // Progress indicator
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue100)
                        .frame(width: 24, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue100)
                        .frame(width: 24, height: 4)
                }
                
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
            
            if let info = presenter.paymentInfo {
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
                
                // Payment details
                VStack(spacing: 0) {
                    // Amount row
                    PaymentDetailRow(
                        label: "Amount",
                        value: info.formattedAmount
                    )
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Pay with row (option selector)
                    Button(action: {
                        showOptionPicker = true
                    }) {
                        HStack {
                            Text("Pay with")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.grey50)
                            
                            Spacer()
                            
                            if let option = presenter.selectedOption {
                                HStack(spacing: 8) {
                                    Text(option.formattedAmount)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(.grey8)
                                    
                                    // Token icon
                                    TokenIcon(iconUrl: option.amount.display.iconUrl, symbol: option.amount.display.assetSymbol, size: 24)
                                    
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.grey50)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Network row
                    if let option = presenter.selectedOption,
                       let networkName = option.amount.display.networkName {
                        HStack {
                            Text("Network")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.grey50)
                            
                            Spacer()
                            
                            Text(networkName)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.grey8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
                .background(Color.grey95.opacity(0.3))
                .cornerRadius(16)
                .padding(.top, 24)
                
                Spacer()
                    .frame(minHeight: 20, maxHeight: 40)
                
                // Pay button
                Button(action: {
                    presenter.confirmPayment()
                }) {
                    if presenter.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Pay \(info.formattedAmount)")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .padding(.vertical, 16)
                    }
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue100, .blue200]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(16)
                .disabled(presenter.isLoading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .sheet(isPresented: $showOptionPicker) {
            OptionPickerSheet(
                options: presenter.paymentOptions,
                selectedOption: presenter.selectedOption,
                onSelect: { option in
                    presenter.selectOption(option)
                    showOptionPicker = false
                }
            )
            .presentationDetents([.medium])
        }
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

struct PaymentDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.grey50)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.grey8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct OptionPickerSheet: View {
    let options: [PaymentOption]
    let selectedOption: PaymentOption?
    let onSelect: (PaymentOption) -> Void
    
    var body: some View {
        NavigationView {
            List(options, id: \.id) { option in
                Button(action: {
                    onSelect(option)
                }) {
                    HStack(spacing: 12) {
                        // Token icon
                        TokenIcon(iconUrl: option.amount.display.iconUrl, symbol: option.amount.display.assetSymbol, size: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.amount.display.assetName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if let networkName = option.amount.display.networkName {
                                Text("on \(networkName)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(option.amount.display.assetSymbol)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(option.formattedAmount)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        if selectedOption?.id == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select Payment Option")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Token Icon Component

struct TokenIcon: View {
    let iconUrl: String?
    let symbol: String
    let size: CGFloat
    
    var body: some View {
        if let iconUrl = iconUrl, let url = URL(string: iconUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    tokenPlaceholder
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                @unknown default:
                    tokenPlaceholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            tokenPlaceholder
        }
    }
    
    private var tokenPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.grey95)
            Text(String(symbol.prefix(1)))
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.grey50)
        }
        .frame(width: size, height: size)
    }
}

#if DEBUG
struct PayConfirmView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayConfirmView()
        }
    }
}
#endif
