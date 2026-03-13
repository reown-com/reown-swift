import SwiftUI

struct ChainInfo: Identifiable {
    let id: String
    let name: String
    let iconName: String?
}

struct NetworkSelectorView: View {
    let chains: [ChainInfo]
    @Binding var selectedChainIds: Set<String>
    @State private var isExpanded = false

    private var selectedChainIdsOrdered: [String] {
        chains.map(\.id).filter { selectedChainIds.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing._3) {
                    Text("Network")
                        .appFont(.lg)
                        .foregroundColor(AppColors.textTertiary)

                    Spacer()

                    ChainIconsView(
                        chainIds: selectedChainIdsOrdered,
                        size: 24,
                        overlap: 8,
                        maxVisible: 5
                    )

                    if chains.count > 1 {
                        CaretUpDownIcon(color: AppColors.iconInvert)
                    }
                }
                .padding(Spacing._5)
            }
            .disabled(chains.count <= 1)

            // Expanded chain list
            if isExpanded {
                ScrollView {
                    VStack(spacing: Spacing._2) {
                        ForEach(chains) { chain in
                            chainRow(chain: chain)
                        }
                    }
                    .padding(.horizontal, Spacing._5)
                    .padding(.top, Spacing._1)
                    .padding(.bottom, Spacing._5)
                }
                .frame(maxHeight: CGFloat(min(chains.count, 5)) * 68 + CGFloat(max(0, min(chains.count, 5) - 1)) * Spacing._2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColors.foregroundPrimary)
        .cornerRadius(AppRadius._4)
        .clipped()
    }

    private func chainRow(chain: ChainInfo) -> some View {
        let isSelected = selectedChainIds.contains(chain.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedChainIds.remove(chain.id)
                } else {
                    selectedChainIds.insert(chain.id)
                }
            }
        } label: {
            HStack(spacing: Spacing._3) {
                // Chain icon
                chainIcon(for: chain)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                Text(chain.name)
                    .appFont(.md)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // Checkbox — rounded square
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppRadius._2)
                            .fill(AppColors.backgroundAccentPrimary)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.white)
                    } else {
                        RoundedRectangle(cornerRadius: AppRadius._2)
                            .stroke(AppColors.borderSecondary, lineWidth: 1)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .frame(height: 68)
            .padding(.horizontal, Spacing._4)
            .background(
                RoundedRectangle(cornerRadius: AppRadius._4)
                    .fill(isSelected ? AppColors.backgroundAccentPrimary.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius._4)
                    .stroke(isSelected ? AppColors.backgroundAccentPrimary : Color.clear, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func chainIcon(for chain: ChainInfo) -> some View {
        if let assetName = ChainIconProvider.imageName(for: chain.id) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .background(AppColors.foregroundTertiary)
        } else {
            Circle()
                .fill(AppColors.foregroundTertiary)
                .overlay(
                    Text(String(chain.name.prefix(1)))
                        .appFont(.sm, weight: .medium)
                        .foregroundColor(AppColors.textPrimary)
                )
        }
    }
}
