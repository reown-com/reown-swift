import SwiftUI

struct BalancesView: View {
    @EnvironmentObject var viewModel: BalancesViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HeaderView(
                    onScan: { viewModel.onScanOptions() }
                )

                // Total Balance Header
                totalBalanceHeader
                    .padding(.top, Spacing._5)

                // Token Tab Picker
                Picker("Token", selection: $viewModel.selectedTab) {
                    Text("USDC").tag(0)
                    Text("EURC").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing._5)
                .padding(.top, Spacing._3)

                // Chain Balances List
                ScrollView {
                    LazyVStack(spacing: Spacing._3) {
                        ForEach(viewModel.displayedBalances) { chainBalance in
                            chainBalanceRow(chainBalance)
                        }
                    }
                    .padding(.horizontal, Spacing._5)
                    .padding(.top, Spacing._5)
                }
                .refreshable {
                    viewModel.refresh()
                }

                Spacer()
            }
        }
        .alert(viewModel.errorMessage, isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Total Balance Header

    private var totalBalanceHeader: some View {
        VStack(spacing: Spacing._2) {
            Text(viewModel.formattedTotalBalance)
                .appFont(.h1, weight: .medium)
                .foregroundColor(AppColors.textPrimary)

            Text("Total \(viewModel.tokenLabel)")
                .appFont(.lg, weight: .medium)
                .foregroundColor(AppColors.textSecondary)

            Text(viewModel.truncatedAddress)
                .appFont(.md)
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, Spacing._1)
        }
        .padding(.vertical, Spacing._5)
    }

    // MARK: - Chain Balance Row

    private func chainBalanceRow(_ chainBalance: ChainBalance) -> some View {
        HStack(spacing: Spacing._3) {
            VStack(alignment: .leading, spacing: Spacing._05) {
                Text(chainBalance.chain.rawValue)
                    .appFont(.xl, weight: .medium)
                    .foregroundColor(AppColors.textPrimary)

                if let error = chainBalance.error {
                    Text(error)
                        .appFont(.sm)
                        .foregroundColor(AppColors.textError)
                        .lineLimit(1)
                }
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text(chainBalance.formattedBalance)
                    .appFont(.xl, weight: .medium)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .padding(.horizontal, Spacing._4)
        .padding(.vertical, Spacing._4)
        .background(
            RoundedRectangle(cornerRadius: CGFloat(AppRadius._4))
                .fill(AppColors.foregroundPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(AppRadius._4))
                .stroke(AppColors.borderPrimary, lineWidth: 1)
        )
    }
}

#if DEBUG
struct BalancesView_Previews: PreviewProvider {
    static var previews: some View {
        BalancesView()
    }
}
#endif
