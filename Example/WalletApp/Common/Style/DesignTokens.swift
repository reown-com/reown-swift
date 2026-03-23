import SwiftUI
import UIKit

// MARK: - Color System

/// Semantic color system matching the cross-platform design system.
/// Colors adapt automatically to light/dark mode.
enum AppColors {

    // MARK: Background

    static let backgroundPrimary = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x202020) : UIColor(hex: 0xFFFFFF) })
    static let backgroundInvert = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xFFFFFF) : UIColor(hex: 0x202020) })
    static let backgroundAccentPrimary = Color(UIColor(hex: 0x0988F0))
    static let backgroundAccentCertified = Color(UIColor(hex: 0xC7B994))
    static let backgroundSuccess = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 48/255, green: 164/255, blue: 107/255, alpha: 0.2)
        : UIColor(red: 48/255, green: 164/255, blue: 107/255, alpha: 0.2) })
    static let backgroundError = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 223/255, green: 74/255, blue: 52/255, alpha: 0.2)
        : UIColor(red: 223/255, green: 74/255, blue: 52/255, alpha: 0.2) })
    static let backgroundWarning = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 243/255, green: 161/255, blue: 63/255, alpha: 0.2)
        : UIColor(red: 243/255, green: 161/255, blue: 63/255, alpha: 0.2) })

    // MARK: Text

    static let textPrimary = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xFFFFFF) : UIColor(hex: 0x202020) })
    static let textSecondary = Color(UIColor(hex: 0x9A9A9A))
    static let textTertiary = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xBBBBBB) : UIColor(hex: 0x6C6C6C) })
    static let textInvert = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x202020) : UIColor(hex: 0xFFFFFF) })
    static let textAccentPrimary = Color(UIColor(hex: 0x0988F0))
    static let textAccentSecondary = Color(UIColor(hex: 0xC7B994))
    static let textSuccess = Color(UIColor(hex: 0x30A46B))
    static let textError = Color(UIColor(hex: 0xDF4A34))
    static let textWarning = Color(UIColor(hex: 0xF3A13F))

    // MARK: Border

    static let borderPrimary = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x363636) : UIColor(hex: 0xE9E9E9) })
    static let borderSecondary = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x4F4F4F) : UIColor(hex: 0xD0D0D0) })
    static let borderAccentPrimary = Color(UIColor(hex: 0x0988F0))
    static let borderAccentSecondary = Color(UIColor(hex: 0xC7B994))
    static let borderSuccess = Color(UIColor(hex: 0x30A46B))
    static let borderError = Color(UIColor(hex: 0xDF4A34))
    static let borderWarning = Color(UIColor(hex: 0xF3A13F))

    // MARK: Foreground

    static let foregroundPrimary = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x252525) : UIColor(hex: 0xF3F3F3) })
    static let foregroundSecondary = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x2A2A2A) : UIColor(hex: 0xE9E9E9) })
    static let foregroundTertiary = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x363636) : UIColor(hex: 0xD0D0D0) })

    static let foregroundAccentPrimary10 = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 9/255, green: 136/255, blue: 240/255, alpha: 0.1)
        : UIColor(red: 9/255, green: 136/255, blue: 240/255, alpha: 0.1) })
    static let foregroundAccentPrimary10Solid = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x222F39) : UIColor(hex: 0xE6F3FE) })
    static let foregroundAccentPrimary40 = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 9/255, green: 136/255, blue: 240/255, alpha: 0.4)
        : UIColor(red: 9/255, green: 136/255, blue: 240/255, alpha: 0.4) })
    static let foregroundAccentPrimary60 = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 9/255, green: 136/255, blue: 240/255, alpha: 0.6)
        : UIColor(red: 9/255, green: 136/255, blue: 240/255, alpha: 0.6) })
    static let foregroundAccentPrimary90Solid = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x0C7EDC) : UIColor(hex: 0x2294F2) })

    static let foregroundAccentSecondary10 = Color(UIColor(red: 199/255, green: 185/255, blue: 148/255, alpha: 0.1))
    static let foregroundAccentSecondary40 = Color(UIColor(red: 199/255, green: 185/255, blue: 148/255, alpha: 0.4))
    static let foregroundAccentSecondary60 = Color(UIColor(red: 199/255, green: 185/255, blue: 148/255, alpha: 0.6))

    // MARK: Icon

    static let iconDefault = Color(UIColor(hex: 0x9A9A9A))
    static let iconInvert = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xFFFFFF) : UIColor(hex: 0x202020) })
    static let iconAccentPrimary = Color(UIColor(hex: 0x0988F0))
    static let iconAccentSecondary = Color(UIColor(hex: 0xC7B994))
    static let iconSuccess = Color(UIColor(hex: 0x30A46B))
    static let iconError = Color(UIColor(hex: 0xDF4A34))
    static let iconWarning = Color(UIColor(hex: 0xF3A13F))

    // MARK: Others

    static let white = Color(UIColor(hex: 0xFFFFFF))
}

// MARK: - UIColor Design Tokens

extension UIColor {
    static let appBackgroundPrimary = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x202020) : UIColor(hex: 0xFFFFFF) }
    static let appTextSecondary = UIColor(hex: 0x9A9A9A)
    static let appAccentPrimary = UIColor(hex: 0x0988F0)
    static let appBorderPrimary = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x363636) : UIColor(hex: 0xE9E9E9) }
}

// MARK: - UIColor hex initializer

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
