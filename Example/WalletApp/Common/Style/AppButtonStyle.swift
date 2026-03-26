import SwiftUI

// MARK: - Primary Button Style

/// Filled blue accent button - used for main actions (Connect, Sign, Confirm)
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing._2) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
            configuration.label
        }
        .appFont(.lg)
        .foregroundColor(.white)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .frame(height: Spacing._11)
        .background(AppColors.backgroundAccentPrimary)
        .cornerRadius(AppRadius._4)
        .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Secondary Button Style

/// Outlined/light background button - used for secondary actions (Cancel)
struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.lg, weight: .medium)
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: Spacing._11)
            .background(AppColors.foregroundPrimary)
            .cornerRadius(AppRadius._4)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Destructive Button Style

/// Red-tinted button for decline/reject actions
struct DestructiveButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(.lg, weight: .medium)
            .foregroundColor(AppColors.textError)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: Spacing._11)
            .background(AppColors.backgroundError)
            .cornerRadius(AppRadius._4)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
