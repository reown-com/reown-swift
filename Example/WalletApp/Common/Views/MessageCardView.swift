import SwiftUI

struct MessageCardView: View {
    let message: String
    var title: String = "Message"
    var showTitle: Bool = true
    var maxHeight: CGFloat = 120

    var body: some View {
        if message.isEmpty { EmptyView() } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing._2) {
                    if showTitle {
                        Text(title)
                            .appFont(.lg)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Text(message)
                        .appFont(.md)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Spacing._5)
            }
            .frame(maxHeight: maxHeight)
            .background(AppColors.foregroundPrimary)
            .cornerRadius(AppRadius._3)
        }
    }
}
