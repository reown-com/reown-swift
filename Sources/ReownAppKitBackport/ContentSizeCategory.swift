import SwiftUI

extension ContentSizeCategory {
    var order: Int {
        switch self {
        case .extraSmall: return 0
        case .small: return 1
        case .medium: return 2
        case .large: return 3
        case .extraLarge: return 4
        case .extraExtraLarge: return 5
        case .extraExtraExtraLarge: return 6
        case .accessibilityMedium: return 7
        case .accessibilityLarge: return 8
        case .accessibilityExtraLarge: return 9
        case .accessibilityExtraExtraLarge: return 10
        case .accessibilityExtraExtraExtraLarge: return 11
        @unknown default: fatalError("Unknown content size category")
        }
    }
}

extension ContentSizeCategory: Comparable {
    public static func < (lhs: ContentSizeCategory, rhs: ContentSizeCategory) -> Bool {
        lhs.order < rhs.order
    }
}
