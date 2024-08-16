import SwiftUI

public struct W3MTag: View {
    public enum Variant: String, CaseIterable, Identifiable {
        case main = "MAIN"
        case info = "INFO"
        case success = "SUCCESS"
        case error = "ERROR"
        case inProgress = "IN PROGRESS"
        case warning = "WARNING"
        case disabled = "DISABLED"

        var backgroundColor: Color {
            switch self {
            case .main:
                return Color.Overblue015
            case .info:
                return Color.Overgray010
            case .success:
                return Color.Success100.opacity(0.15)
            case .error:
                return Color.Error100.opacity(0.15)
            case .inProgress:
                return Color(red: 0.84, green: 0.85, blue: 0.09).opacity(0.15)
            case .warning:
                return Color.Orange100.opacity(0.15)
            case .disabled:
                return Color.Overgray015.opacity(0.15)
            }
        }
        
        var textColor: Color {
            switch self {
            case .main:
                return Color.Blue100
            case .info:
                return Color.Foreground150
            case .success:
                return Color.Success100
            case .error:
                return Color.Error100
            case .inProgress:
                return Color(red: 0.84, green: 0.85, blue: 0.09)
            case .warning:
                return Color.Orange100
            case .disabled:
                return Color.Overgray015
            }
        }
        
        public var id: Self {
            return self
        }
    }

    let title: String
    let variant: Variant
    
    @Backport.ScaledMetric var scale: CGFloat = 1

    public init(title: String, variant: Variant) {
        self.title = title
        self.variant = variant
    }
    
    public var body: some View {
        Text(title)
            .font(.micro700)
            .lineLimit(1)
            .foregroundColor(variant.textColor)
            .padding(Spacing.xxxs * scale)
            .background(variant.backgroundColor)
            .cornerRadius(Radius.xxxxxs * scale)
    }
}

#if DEBUG
    public struct W3MTagPreviewView: View {
        public init() {}

        public var body: some View {
            VStack {
                ForEach(W3MTag.Variant.allCases) {
                    W3MTag(title: $0.rawValue, variant: $0)
                }
            }
            .padding()
            .background(Color.Overgray002)
        }
    }

    struct W3MTag_Preview: PreviewProvider {
        static var previews: some View {
            W3MTagPreviewView()
                .previewLayout(.sizeThatFits)
        }
    }

#endif
