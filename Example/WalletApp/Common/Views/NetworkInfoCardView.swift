import SwiftUI

/// Read-only card displaying the network for a session request.
/// Shows "Network" label on the left and chain icon on the right.
struct NetworkInfoCardView: View {
    let chainId: String

    var body: some View {
        HStack {
            Text("Network")
                .appFont(.lg)
                .foregroundColor(AppColors.textTertiary)

            Spacer()

            ChainIconsView(chainIds: [chainId], size: 24, maxVisible: 1)
        }
        .padding(Spacing._5)
        .background(AppColors.foregroundPrimary)
        .cornerRadius(AppRadius._3)
    }
}
