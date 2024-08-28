import SwiftUI

public enum W3MFont {
    case large500
    case large600
    case large700
    case micro600
    case micro700
    case paragraph500
    case paragraph600
    case paragraph700
    case small400
    case small500
    case small600
    case tiny500
    case tiny600
    case title500
    case title600
    case title700
    
    var weight: Font.Weight {
        switch self {
        case .large500: return .medium
        case .large600: return .semibold
        case .large700: return .bold
        case .micro600: return .semibold
        case .micro700: return .bold
        case .paragraph500: return .medium
        case .paragraph600: return .semibold
        case .paragraph700: return .bold
        case .small400: return .regular
        case .small500: return .medium
        case .small600: return .semibold
        case .tiny500: return .medium
        case .tiny600: return .semibold
        case .title500: return .medium
        case .title600: return .semibold
        case .title700: return .bold
        }
    }
    
    var size: CGFloat {
        switch self {
        case .large500: return 20.0
        case .large600: return 20.0
        case .large700: return 20.0
        case .micro600: return 10.0
        case .micro700: return 10.0
        case .paragraph500: return 16.0
        case .paragraph600: return 16.0
        case .paragraph700: return 16.0
        case .small400: return 14.0
        case .small500: return 14.0
        case .small600: return 14.0
        case .tiny500: return 12.0
        case .tiny600: return 12.0
        case .title500: return 24.0
        case .title600: return 24.0
        case .title700: return 24.0
        }
    }
}

struct ScaledFont: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    
    var size: Double
    var weight: Font.Weight

    func body(content: Content) -> some View {
        let scaledSize = UIFontMetrics.default.scaledValue(for: size)
        return content.font(.system(size: scaledSize, weight: weight))
    }
}

extension View {
    public func scaledFont(size: Double, weight: Font.Weight) -> some View {
        return modifier(ScaledFont(size: size, weight: weight))
    }
    
    public func font(_ font: W3MFont) -> some View {
        return modifier(ScaledFont(size: font.size, weight: font.weight))
    }
}

struct FontPreviews: PreviewProvider {
    @Environment(\.sizeCategory) var sizeCategory
    
    static var previews: some View {
        VStack(spacing: 10) {
            Group {
                Text("large500").font(.large500)
                Text("large600").font(.large600)
                Text("large700").font(.large700)
            }
            Group {
                Text("title500").font(.title500)
                Text("title600").font(.title600)
                Text("title700").font(.title700)
            }
            Group {
                Text("paragraph500").font(.paragraph500)
                Text("paragraph600").font(.paragraph600)
                Text("paragraph700").font(.paragraph700)
            }
            Group {
                Text("micro600").font(.micro600)
                Text("micro700").font(.micro700)
            }
            Group {
                Text("small500").font(.small500)
                Text("small600").font(.small600)
            }
            Group {
                Text("tiny500").font(.tiny500)
                Text("tiny600").font(.tiny600)
            }
        }
    }
}
