import SwiftUI
import UIKit

// MARK: - Typography System

enum AppTextSize: CGFloat {
    case h1 = 50
    case h2 = 44
    case h3 = 38
    case h4 = 32
    case h5 = 26
    case h6 = 20
    case xl = 18
    case lg = 16
    case md = 14
    case sm = 12
}

enum AppFontWeight {
    case light
    case regular
    case medium

    var fontName: String {
        switch self {
        case .light: return "KHTeka-Light"
        case .regular: return "KHTeka-Regular"
        case .medium: return "KHTeka-Medium"
        }
    }

    var swiftUIWeight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        }
    }
}

enum AppFont {

    // Cache fonts to avoid repeated UIFont(name:size:) lookups during scroll
    private static var fontCache: [String: Font] = [:]
    private static let cacheLock = NSLock()

    static func font(size: AppTextSize, weight: AppFontWeight = .regular) -> Font {
        let key = "\(weight.fontName)-\(size.rawValue)"
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = fontCache[key] {
            return cached
        }

        let font: Font
        if let uiFont = UIFont(name: weight.fontName, size: size.rawValue) {
            font = Font(uiFont)
        } else {
            font = .custom(weight.fontName, fixedSize: size.rawValue)
        }

        fontCache[key] = font
        return font
    }

    // MARK: Headings

    static func h1(weight: AppFontWeight = .regular) -> Font { font(size: .h1, weight: weight) }
    static func h2(weight: AppFontWeight = .regular) -> Font { font(size: .h2, weight: weight) }
    static func h3(weight: AppFontWeight = .regular) -> Font { font(size: .h3, weight: weight) }
    static func h4(weight: AppFontWeight = .regular) -> Font { font(size: .h4, weight: weight) }
    static func h5(weight: AppFontWeight = .regular) -> Font { font(size: .h5, weight: weight) }
    static func h6(weight: AppFontWeight = .regular) -> Font { font(size: .h6, weight: weight) }

    // MARK: Body

    static func xl(weight: AppFontWeight = .regular) -> Font { font(size: .xl, weight: weight) }
    static func lg(weight: AppFontWeight = .regular) -> Font { font(size: .lg, weight: weight) }
    static func md(weight: AppFontWeight = .regular) -> Font { font(size: .md, weight: weight) }
    static func sm(weight: AppFontWeight = .regular) -> Font { font(size: .sm, weight: weight) }
}

// MARK: - Tracking (letter spacing)

/// Letter spacing percentages matching the cross-platform design system (RN Text.tsx).
enum AppTracking {
    static func value(for size: AppTextSize) -> CGFloat {
        switch size {
        case .h1, .h2, .h3: return size.rawValue * -0.02
        case .h4, .h5: return size.rawValue * -0.01
        case .h6: return size.rawValue * -0.03
        case .xl, .lg, .md, .sm: return size.rawValue * -0.01
        }
    }
}

// MARK: - View Modifier

struct AppFontModifier: ViewModifier {
    let size: AppTextSize
    let weight: AppFontWeight

    func body(content: Content) -> some View {
        content
            .font(AppFont.font(size: size, weight: weight))
            .tracking(AppTracking.value(for: size))
    }
}

extension View {
    func appFont(_ size: AppTextSize, weight: AppFontWeight = .regular) -> some View {
        modifier(AppFontModifier(size: size, weight: weight))
    }
}
