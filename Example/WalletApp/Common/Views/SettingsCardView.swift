import SwiftUI

struct SettingsCardView: View {
    let title: String
    var value: String? = nil
    var showToggle: Bool = false
    @Binding var isOn: Bool
    var onTap: (() -> Void)? = nil

    var body: some View {
        if showToggle {
            cardContent
        } else {
            Button {
                onTap?()
            } label: {
                cardContent
            }
            .buttonStyle(.plain)
        }
    }

    private var cardContent: some View {
        HStack {
            Text(title)
                .appFont(.lg)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if showToggle {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(AppColors.backgroundAccentPrimary)
            } else if let value = value {
                Text(value)
                    .appFont(.md)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Spacing._6)
        .frame(height: 76)
        .background(AppColors.foregroundPrimary)
        .cornerRadius(AppRadius._5)
    }
}

// MARK: - Convenience initializers

extension SettingsCardView {

    /// Navigation card — tappable with title only
    static func navigation(_ title: String, onTap: @escaping () -> Void) -> SettingsCardView {
        SettingsCardView(
            title: title,
            isOn: .constant(false),
            onTap: onTap
        )
    }

    /// Toggle card — title with a toggle switch
    static func toggle(_ title: String, isOn: Binding<Bool>) -> SettingsCardView {
        SettingsCardView(
            title: title,
            showToggle: true,
            isOn: isOn
        )
    }

    /// Info card — title + secondary value text, tappable
    static func info(_ title: String, value: String, onTap: (() -> Void)? = nil) -> SettingsCardView {
        SettingsCardView(
            title: title,
            value: value,
            isOn: .constant(false),
            onTap: onTap
        )
    }
}
