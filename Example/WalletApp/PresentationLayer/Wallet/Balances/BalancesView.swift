import SwiftUI

struct BalancesView: View {
    @EnvironmentObject var viewModel: BalancesViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Total Balance Header
                totalBalanceHeader
                    .padding(.top, 20)
                
                // Chain Balances List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.chainBalances) { chainBalance in
                            chainBalanceRow(chainBalance)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .refreshable {
                    viewModel.refresh()
                }
                
                Spacer()
                
                // Action Buttons
                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .alert(viewModel.errorMessage, isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
    
    // MARK: - Total Balance Header
    
    private var totalBalanceHeader: some View {
        VStack(spacing: 8) {
            Text(viewModel.formattedTotalBalance)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(Color(UIColor.label))
            
            Text("Total USDC")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color(UIColor.secondaryLabel))
            
            Text(viewModel.truncatedAddress)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .padding(.top, 4)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Chain Balance Row
    
    private func chainBalanceRow(_ chainBalance: ChainBalance) -> some View {
        HStack(spacing: 12) {
            // Chain name
            VStack(alignment: .leading, spacing: 2) {
                Text(chainBalance.chain.rawValue)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(UIColor.label))
                
                if let error = chainBalance.error {
                    Text(error)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Balance
            if chainBalance.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text(chainBalance.formattedBalance)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(UIColor.label))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Spacer()
            
            // Pay button
            Button {
                viewModel.onTestPay()
            } label: {
                Image(systemName: "creditcard.fill")
                    .resizable()
                    .frame(width: 40, height: 28)
                    .foregroundColor(.blue100)
            }
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .accessibilityIdentifier("testPay")
            
            // Paste button
            Button {
                viewModel.onPasteUri()
            } label: {
                Image("copy")
                    .resizable()
                    .frame(width: 56, height: 56)
            }
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .accessibilityIdentifier("copy")
            
            // Scan button
            Button {
                viewModel.onScanUri()
            } label: {
                Image("scan")
                    .resizable()
                    .frame(width: 56, height: 56)
            }
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .accessibilityIdentifier("scan")
        }
    }
}

#if DEBUG
struct BalancesView_Previews: PreviewProvider {
    static var previews: some View {
        BalancesView()
    }
}
#endif


