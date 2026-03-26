import SwiftUI

/// Overlapping chain icon stack, matching the RN `ChainIcons` component.
/// Used in NetworkSelectorView headers, connected apps cards, and connection detail screens.
struct ChainIconsView: View {
    let chainIds: [String]
    var size: CGFloat = 24
    var overlap: CGFloat = 8
    var maxVisible: Int = 5

    private var uniqueIds: [String] {
        var seen = Set<String>()
        return chainIds.filter { seen.insert($0).inserted }
    }

    private var visibleIds: [String] {
        Array(uniqueIds.prefix(maxVisible))
    }

    private var remainingCount: Int {
        max(0, uniqueIds.count - maxVisible)
    }

    private var borderWidth: CGFloat { 2 }
    private var wrapperSize: CGFloat { size + borderWidth * 2 }

    var body: some View {
        let step = wrapperSize - overlap

        HStack(spacing: -overlap) {
            ForEach(Array(visibleIds.enumerated()), id: \.element) { index, chainId in
                ZStack {
                    Circle()
                        .fill(AppColors.foregroundPrimary)
                        .frame(width: wrapperSize, height: wrapperSize)

                    chainIconImage(chainId: chainId)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                }
                .zIndex(Double(index))
            }

            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .appFont(.sm, weight: .medium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, Spacing._2)
                    .frame(minWidth: 36, minHeight: wrapperSize)
                    .background(AppColors.foregroundTertiary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.foregroundPrimary, lineWidth: 1))
                    .zIndex(Double(visibleIds.count))
            }
        }
    }

    @ViewBuilder
    private func chainIconImage(chainId: String) -> some View {
        if let name = ChainIconProvider.imageName(for: chainId) {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Circle()
                .fill(AppColors.foregroundTertiary)
        }
    }
}
