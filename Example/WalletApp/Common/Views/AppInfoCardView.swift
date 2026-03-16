import SwiftUI
import ReownWalletKit

struct AppInfoCardView: View {
    let domain: String
    let validationStatus: VerifyContext.ValidationStatus?
    var isExpanded: Bool = false
    var onToggle: (() -> Void)?

    @State private var internalExpanded = false

    private var expanded: Bool {
        onToggle != nil ? isExpanded : internalExpanded
    }

    private var toggle: () -> Void {
        onToggle ?? { withAnimation(.easeInOut(duration: 0.25)) { internalExpanded.toggle() } }
    }

    private var formattedDomain: String {
        var d = domain
        if let url = URL(string: d), let host = url.host {
            d = host
        }
        if d.hasPrefix("www.") {
            d = String(d.dropFirst(4))
        }
        return d
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: toggle) {
                HStack {
                    Text(formattedDomain)
                        .appFont(.lg)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    VerifyBadgeView(status: validationStatus)

                    CaretUpDownIcon(color: AppColors.iconInvert)
                }
                .padding(Spacing._5)
            }

            // Expandable permissions
            if expanded {
                VStack(spacing: Spacing._3) {
                    permissionRow(icon: "checkmark.circle.fill", text: "View your balance & activity", color: AppColors.iconSuccess)
                    permissionRow(icon: "checkmark.circle.fill", text: "Request transaction approvals", color: AppColors.iconSuccess)
                    permissionRow(icon: "xmark.circle.fill", text: "Move funds without permission", color: AppColors.iconError)
                }
                .padding(.horizontal, Spacing._5)
                .padding(.bottom, Spacing._5)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColors.foregroundPrimary)
        .cornerRadius(AppRadius._3)
        .clipped()
    }

    private func permissionRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: Spacing._2) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 20, height: 20)

            Text(text)
                .appFont(.md)
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
    }
}
