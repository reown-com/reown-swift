import SwiftUI

public struct W3MActionEntryStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    @Backport.ScaledMetric var scale: CGFloat = 1

    var leftIcon: Image?
    var rightIcon: Image?
    
    var isPressedOverride: Bool?
    
    public init(
        leftIcon: Image? = nil,
        rightIcon: Image? = nil
    ) {
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
    }
    
    #if DEBUG
    init(
        leftIcon: Image? = nil,
        rightIcon: Image? = nil,
        isPressedOverride: Bool?
    ) {
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.isPressedOverride = isPressedOverride
    }
    #endif

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xs) {
            if let leftIcon {
                leftIcon
                    .resizable()
                    .frame(width: 14 * scale, height: 14 * scale)
            }
            
            configuration.label
            
            if let rightIcon {
                rightIcon
                    .resizable()
                    .frame(width: 14 * scale, height: 14 * scale)
            }
        }
        .font(.paragraph600)
        .foregroundColor((isPressedOverride ?? configuration.isPressed) ? .Foreground150 : .Foreground200)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .opacity(isEnabled ? 1 : 0.5)
        .padding(.vertical, Spacing.xs * scale)
        .padding(.leading, Spacing.xs * scale)
        .padding(.trailing, Spacing.xs * scale)
        .backport
        .background { (isPressedOverride ?? configuration.isPressed) ? Color.GrayGlass010 : Color.GrayGlass002 }
        .cornerRadius(Radius.xs * scale)
    }
}

#if DEBUG
    public struct W3MActionEntryStylePreviewView: View {
        public init() {}

        public var body: some View {
            ScrollView {
                VStack {
                    Button(action: {}, label: {
                        Text("Copy link")
                    })
                    .buttonStyle(W3MActionEntryStyle(
                        leftIcon: Image.Medium.desktop
                    ))

                    Button(action: {}, label: {
                        Text("Copy link")
                    })
                    .buttonStyle(W3MActionEntryStyle(
                        leftIcon: Image.Regular.copy,
                        isPressedOverride: true
                    ))

                    Button(action: {}, label: {
                        Text("Copy link")
                    })
                    .buttonStyle(W3MActionEntryStyle(
                        leftIcon: Image.Regular.copy
                    ))
                    .disabled(true)
                }
                .padding()

            }
        }
    }

    struct W3MActionEntry_Preview: PreviewProvider {
        static var previews: some View {
            W3MActionEntryStylePreviewView()
                .previewLayout(.sizeThatFits)
        }
    }

#endif
