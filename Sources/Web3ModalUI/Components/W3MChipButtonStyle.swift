import SwiftUI

public struct W3MChipButtonStyle<LeadingImageContent: View, TrailingImageContent: View>: ButtonStyle {
    public enum Variant {
        case fill
        case shade
        case transparent
        
        var textColor: Color {
            switch self {
            case .fill:
                return Color.Inverse100
            case .shade:
                return Color.Foreground200
            case .transparent:
                return Color.Foreground150
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .fill:
                return Color.Blue100
            case .shade:
                return Color.GrayGlass010
            case .transparent:
                return Color.clear
            }
        }
        
        var pressedColor: Color {
            switch self {
            case .fill:
                return Color.Blue080
            case .shade:
                return Color.GrayGlass020
            case .transparent:
                return Color.GrayGlass010
            }
        }
    }
    
    public enum Size {
        case s, m
    }
    
    @Environment(\.isEnabled) var isEnabled
    
    let variant: Variant
    let size: Size
    var leadingImage: () -> LeadingImageContent
    var trailingImage: () -> TrailingImageContent
    
    var isPressedOverride: Bool?
    
    public init(
        variant: Variant = .fill,
        size: Size = .m,
        @ViewBuilder leadingImage: @escaping () -> LeadingImageContent,
        @ViewBuilder trailingImage: @escaping () -> TrailingImageContent
    ) {
        self.variant = variant
        self.size = size
        self.leadingImage = leadingImage
        self.trailingImage = trailingImage
    }
    
    fileprivate init(
        variant: Variant,
        size: Size = .m,
        @ViewBuilder leadingImage: @escaping () -> LeadingImageContent,
        @ViewBuilder trailingImage: @escaping () -> TrailingImageContent,
        isPressedOverride: Bool?
    ) {
        self.variant = variant
        self.size = size
        self.leadingImage = leadingImage
        self.trailingImage = trailingImage
        self.isPressedOverride = isPressedOverride
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        var textColor: Color = variant.textColor
        textColor = isEnabled ? textColor : .Overgray015
        
        var backgroundColor: Color = variant.backgroundColor
        let pressedColor: Color = variant.pressedColor
        backgroundColor = (isPressedOverride ?? configuration.isPressed) ? pressedColor : backgroundColor
        backgroundColor = isEnabled ? backgroundColor : .Overgray010
        
        let verticalPadding = size == .m ? Spacing.xxs : Spacing.xxs
        let horizontalPadding = size == .m ? Spacing.m : Spacing.s
        let leadingPadding = horizontalPadding - (LeadingImageContent.self == EmptyView.self ? 0 : Spacing.xxxs)
        let trailingPadding = horizontalPadding - (TrailingImageContent.self == EmptyView.self ? 0 : Spacing.xxxs)
        
        return HStack(spacing: size == .m ? Spacing.xxs : Spacing.xxxs) {
            leadingImage()
                .clipShape(Circle())
                .saturation(isEnabled ? 1 : 0)
                .opacity(isEnabled ? 1 : 0.5)
                .frame(width: size == .m ? 24 : 16, height: size == .m ? 24 : 16)
    
            configuration
                .label
                .font(.paragraph600)
                .lineLimit(1)
            
            trailingImage()
                .saturation(isEnabled ? 1 : 0)
                .opacity(isEnabled ? 1 : 0.5)
                .frame(width: size == .m ? 14 : 12, height: size == .m ? 14 : 12)
        }
        .foregroundColor(textColor)
        .padding(.vertical, verticalPadding)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .frame(minHeight: size == .m ? 36 : 32)
        .background(backgroundColor)
        .cornerRadius(Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(Color.Overgray010, lineWidth: 1)
        )
    }
}

public extension W3MChipButtonStyle where LeadingImageContent == EmptyView, TrailingImageContent == EmptyView {
    init(
        variant: Variant = .fill,
        size: Size = .m
    ) {
        self.variant = variant
        self.size = size
        self.leadingImage = { EmptyView() }
        self.trailingImage = { EmptyView() }
    }
}

public extension W3MChipButtonStyle where LeadingImageContent == EmptyView {
    init(
        variant: Variant = .fill,
        size: Size = .m,
        @ViewBuilder trailingImage: @escaping () -> TrailingImageContent
    ) {
        self.variant = variant
        self.size = size
        self.leadingImage = { EmptyView() }
        self.trailingImage = trailingImage
    }
}

public extension W3MChipButtonStyle where TrailingImageContent == EmptyView {
    init(
        variant: Variant = .fill,
        size: Size = .m,
        @ViewBuilder leadingImage: @escaping () -> LeadingImageContent
    ) {
        self.variant = variant
        self.size = size
        self.leadingImage = leadingImage
        self.trailingImage = { EmptyView() }
    }
}

#if DEBUG
    public struct W3MChipButtonStylePreviewView: View {
        public init() {}
        
        public var body: some View {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 15) {
                    Group {
                        Text("Fill")
                            .font(.large600)
                        
                        HStack {
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                               W3MChipButtonStyle()
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                               W3MChipButtonStyle(leadingImage: { Image.imageEth.resizable() })
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .fill,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .fill,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: true
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .fill,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            .disabled(true)
                        }
                        
                        Text("Shade")
                            .font(.large600)
                        
                        HStack {
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(variant: .shade)
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                               W3MChipButtonStyle(variant: .shade, leadingImage: { Image.imageEth.resizable() })
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .shade,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .shade,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: true
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .shade,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            .disabled(true)
                        }
                        
                        Text("Transparent")
                            .font(.large600)
                        
                        HStack {
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(variant: .transparent)
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                               W3MChipButtonStyle(variant: .transparent, leadingImage: { Image.imageEth.resizable() })
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .transparent,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .transparent,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: true
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .transparent,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            .disabled(true)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 24)
                    
                    Group {
                        
                        Text("Fill S")
                            .font(.large600)
                        
                        HStack {
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(size: .s)
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(size: .s, leadingImage: { Image.imageEth.resizable() })
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .fill,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .fill,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: true
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .fill,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            .disabled(true)
                        }
                        
                        Text("Shade S")
                            .font(.large600)
                        
                        HStack {
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(variant: .shade, size: .s)
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(variant: .shade, size: .s, leadingImage: { Image.imageEth.resizable() })
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .shade,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .shade,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: true
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .shade,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            .disabled(true)
                        }
                        
                        Text("Transparent S")
                            .font(.large600)
                        
                        HStack {
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(variant: .transparent, size: .s)
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(variant: .transparent, size: .s, leadingImage: { Image.imageEth.resizable() })
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .transparent,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .transparent,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: true
                                )
                            )
                            
                            Button(action: {}) {
                                Text("Button")
                            }
                            .buttonStyle(
                                W3MChipButtonStyle(
                                    variant: .transparent,
                                    size: .s,
                                    leadingImage: { Image.imageEth.resizable() },
                                    trailingImage: { Image.Medium.externalLink.resizable() },
                                    isPressedOverride: nil
                                )
                            )
                            .disabled(true)
                        }
                    }
                }
                .padding()
                .background(Color.Overgray002)
            }
        }
    }

    struct W3MChipButtonStyle_Preview: PreviewProvider {
        static var previews: some View {
            W3MChipButtonStylePreviewView()
        }
    }

#endif
