import SwiftUI

struct PayConfirmView: View {
    @EnvironmentObject var presenter: PayPresenter
    @State private var showAssetPicker = false
    @State private var showNetworkPicker = false
    
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
            
            if let options = presenter.paymentOptions {
                // Merchant icon
                AsyncImage(url: URL(string: options.merchant.iconUrl)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.grey95)
                            Text(String(options.merchant.name.prefix(1)))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.grey8)
                        }
                    }
                }
                .frame(width: 64, height: 64)
                .cornerRadius(12)
                .padding(.top, 16)
                
                // Payment title
                HStack(spacing: 6) {
                    Text("Pay \(options.formattedAmount) to \(options.merchant.name)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.grey8)
                    
                    if options.merchant.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 16)
                
                // Payment details
                VStack(spacing: 0) {
                    // Amount row
                    PaymentDetailRow(
                        label: "Amount",
                        value: options.formattedAmount
                    )
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Pay with row (asset selector)
                    Button(action: {
                        showAssetPicker = true
                    }) {
                        HStack {
                            Text("Pay with")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.grey50)
                            
                            Spacer()
                            
                            if let asset = presenter.selectedAsset {
                                HStack(spacing: 8) {
                                    Text(formatAssetAmount(options.amount, asset: asset))
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(.grey8)
                                    
                                    AsyncImage(url: URL(string: asset.iconUrl)) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } else {
                                            Circle()
                                                .fill(Color.grey95)
                                        }
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    
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
                    Button(action: {
                        showNetworkPicker = true
                    }) {
                        HStack {
                            Text("Network")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.grey50)
                            
                            Spacer()
                            
                            if let network = presenter.selectedNetwork {
                                HStack(spacing: 8) {
                                    AsyncImage(url: URL(string: network.iconUrl)) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } else {
                                            Circle()
                                                .fill(Color.grey95)
                                        }
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.grey50)
                                }
                            }
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
                    presenter.executePayment()
                }) {
                    if presenter.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Pay \(options.formattedAmount)")
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
        .sheet(isPresented: $showAssetPicker) {
            AssetPickerSheet(
                assets: presenter.paymentOptions?.availableAssets ?? [],
                selectedAsset: presenter.selectedAsset,
                onSelect: { asset in
                    presenter.selectAsset(asset)
                    showAssetPicker = false
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showNetworkPicker) {
            NetworkPickerSheet(
                networks: presenter.paymentOptions?.availableNetworks ?? [],
                selectedNetwork: presenter.selectedNetwork,
                onSelect: { network in
                    presenter.selectNetwork(network)
                    showNetworkPicker = false
                }
            )
            .presentationDetents([.medium])
        }
    }
    
    private func formatAssetAmount(_ usdAmount: Double, asset: PaymentAsset) -> String {
        let assetAmount = usdAmount / asset.price
        if asset.assetSymbol == "USDC" || asset.assetSymbol == "USDT" {
            return String(format: "%.2f %@", assetAmount, asset.assetSymbol)
        } else {
            return String(format: "%.4f %@", assetAmount, asset.assetSymbol)
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

struct AssetPickerSheet: View {
    let assets: [PaymentAsset]
    let selectedAsset: PaymentAsset?
    let onSelect: (PaymentAsset) -> Void
    
    var body: some View {
        NavigationView {
            List(assets) { asset in
                Button(action: {
                    onSelect(asset)
                }) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: asset.iconUrl)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Circle()
                                    .fill(Color.grey95)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.assetName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(asset.networkName)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(asset.formattedBalance)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(asset.formattedPrice)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        if selectedAsset?.id == asset.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select Asset")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct NetworkPickerSheet: View {
    let networks: [PaymentNetwork]
    let selectedNetwork: PaymentNetwork?
    let onSelect: (PaymentNetwork) -> Void
    
    var body: some View {
        NavigationView {
            List(networks) { network in
                Button(action: {
                    onSelect(network)
                }) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: network.iconUrl)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Circle()
                                    .fill(Color.grey95)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        Text(network.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedNetwork?.id == network.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select Network")
            .navigationBarTitleDisplayMode(.inline)
        }
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
