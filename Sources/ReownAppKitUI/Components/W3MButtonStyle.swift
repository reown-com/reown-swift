import SwiftUI

public struct W3MButtonStyle: ButtonStyle {
    public enum Size {
        case s, m
    }
    
    public enum Variant {
        case accent
        case main
    }
    
    @Environment(\.isEnabled) var isEnabled
    
    let size: Size
    let variant: Variant
    var leftIcon: Image?
    var rightIcon: Image?
    
    var isPressedOverride: Bool?
    
    public init(
        size: Size = .m,
        variant: Variant = .main,
        leftIcon: Image? = nil,
        rightIcon: Image? = nil
    ) {
        self.size = size
        self.variant = variant
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
    }
    
    fileprivate init(
        size: Size = .m,
        variant: Variant = .main,
        leftIcon: Image? = nil,
        rightIcon: Image? = nil,
        isPressedOverride: Bool?
    ) {
        self.size = size
        self.variant = variant
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.isPressedOverride = isPressedOverride
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        var textColor: Color = variant == .accent ? .Blue100 : .Inverse100
        textColor = isEnabled ? textColor : .Overgray015
        
        var backgroundColor: Color = variant == .accent ? .clear : .Blue100
        let pressedColor: Color = variant == .accent ? .Overgray010 : .Blue080
        backgroundColor = (isPressedOverride ?? configuration.isPressed) ? pressedColor : backgroundColor
        backgroundColor = isEnabled ? backgroundColor : .Overgray010
        
        let verticalPadding = size == .m ? Spacing.xs : Spacing.xxs
        let horizontalPadding = size == .m ? Spacing.l : Spacing.s
        let leadingPadding = horizontalPadding - (leftIcon == nil ? 0 : Spacing.xxxs)
        let trailingPadding = horizontalPadding - (rightIcon == nil ? 0 : Spacing.xxxs)
        let iconSize: CGFloat = size == .m ? 16 : 14
        
        return HStack(spacing: size == .m ? Spacing.xxs : Spacing.xxxs) {
            if let leftIcon {
                leftIcon
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(textColor)
            }
    
            configuration
                .label
                .lineLimit(1)
                .font(size == .m ? .paragraph600 : .small600)
                .foregroundColor(textColor)
            
            if let rightIcon {
                rightIcon
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(textColor)
            }
        }
        .padding(.vertical, verticalPadding)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .frame(height: size == .m ? 40 : 32)
        .background(backgroundColor)
        .cornerRadius(Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(Color.Overgray010, lineWidth: 1)
        )
    }
}

#if DEBUG
    public struct W3MButtonStylePreviewView: View {
        public init() {}
        
        public var body: some View {
            VStack(alignment: .leading) {
                Text("S")
                    .font(.title700)
                
                Text("Main")
                    .font(.large500)
                
                VStack(alignment: .leading) {
                    HStack {
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, leftIcon: .Medium.desktop))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, rightIcon: .Medium.mobile, isPressedOverride: true))
                    }
                    
                    HStack {
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, leftIcon: .Medium.desktop, rightIcon: .Medium.mobile))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, leftIcon: .Medium.desktop, rightIcon: .Medium.mobile))
                        .disabled(true)
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s))
                        .disabled(true)
                    }
                }
                
                Text("Accent")
                    .font(.large500)
                
                VStack(alignment: .leading) {
                    HStack {
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, variant: .accent))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, variant: .accent, leftIcon: .Medium.desktop))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, variant: .accent, rightIcon: .Medium.mobile, isPressedOverride: true))
                    }
                    
                    HStack {
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, variant: .accent, leftIcon: .Medium.desktop, rightIcon: .Medium.mobile))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, variant: .accent, leftIcon: .Medium.desktop, rightIcon: .Medium.mobile))
                        .disabled(true)
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(size: .s, variant: .accent))
                        .disabled(true)
                    }
                }
                
                Text("M")
                    .font(.title700)
                
                Text("Main")
                    .font(.large500)
                
                VStack(alignment: .leading) {
                    HStack {
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle())
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(leftIcon: .Medium.desktop))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(rightIcon: .Medium.mobile, isPressedOverride: true))
                    }
                    
                    HStack {
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(leftIcon: .Medium.desktop, rightIcon: .Medium.mobile))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(leftIcon: .Medium.desktop, rightIcon: .Medium.mobile))
                        .disabled(true)
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle())
                        .disabled(true)
                    }
                }
                
                Text("Accent")
                    .font(.large500)
                
                VStack(alignment: .leading) {
                    HStack {
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(variant: .accent))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(variant: .accent, leftIcon: .Medium.desktop))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(variant: .accent, rightIcon: .Medium.mobile, isPressedOverride: true))
                    }
                    
                    HStack {
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(variant: .accent, leftIcon: .Medium.desktop, rightIcon: .Medium.mobile))
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(variant: .accent, leftIcon: .Medium.desktop, rightIcon: .Medium.mobile))
                        .disabled(true)
                        
                        Button(action: {}) {
                            Text("Button")
                        }
                        .buttonStyle(W3MButtonStyle(variant: .accent))
                        .disabled(true)
                    }
                }
            }
            .padding()
            .background(Color.Overgray002)
        }
    }

    struct W3MButtonStyle_Preview: PreviewProvider {
        static var previews: some View {
            W3MButtonStylePreviewView()
        }
    }

#endif
