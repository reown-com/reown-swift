import SwiftUI

struct WCModalHeaderView: View {
    let appName: String
    let appIconUrl: String?
    let intention: String
    var isLinkMode: Bool = false

    var body: some View {
        VStack(spacing: Spacing._2) {
            // Link mode badge
            if isLinkMode {
                Text("LINK MODE")
                    .appFont(.sm)
                    .foregroundColor(AppColors.textInvert)
                    .frame(width: 100, height: 25)
                    .background(AppColors.backgroundAccentPrimary)
                    .cornerRadius(AppRadius._1)
            }

            // App icon
            if let iconUrl = appIconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        appIconPlaceholder
                    }
                }
                .frame(width: 64, height: 64)
                .cornerRadius(AppRadius._3)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius._3)
                        .stroke(AppColors.borderPrimary, lineWidth: 1)
                )
            } else {
                appIconPlaceholder
            }

            // Intent title
            Text("\(intention) \(appName)")
                .appFont(.h6)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, Spacing._2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing._4)
    }

    private var appIconPlaceholder: some View {
        RoundedRectangle(cornerRadius: AppRadius._3)
            .fill(AppColors.foregroundPrimary)
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: "app.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.textSecondary)
            )
    }
}
