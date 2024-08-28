import SwiftUI

public struct W3MListSelectStyle<ImageContent: View>: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.sizeCategory) var sizeCategory

    @Backport.ScaledMetric var scale: CGFloat = 1

    var imageContent: (CGFloat) -> ImageContent
    var tag: W3MTag?
    var showChevron: Bool

    var isPressedOverride: Bool?

    public init(
        @ViewBuilder imageContent: @escaping (CGFloat) -> ImageContent,
        tag: W3MTag? = nil,
        showChevron: Bool = false
    ) {
        self.imageContent = imageContent
        self.tag = tag
        self.showChevron = showChevron
    }

    #if DEBUG
        init(
            @ViewBuilder imageContent: @escaping (CGFloat) -> ImageContent,
            tag: W3MTag? = nil,
            isPressedOverride: Bool? = nil,
            showChevron: Bool = false
        ) {
            self.imageContent = imageContent
            self.tag = tag
            self.isPressedOverride = isPressedOverride
            self.showChevron = showChevron
        }
    #endif

    public func makeBody(configuration: Configuration) -> some View {
        let layoutBreakCondition = sizeCategory >= .accessibilityMedium
        
        AdaptiveStack(
            condition: layoutBreakCondition,
            horizontalAlignment: .center,
            spacing: 10 * scale
        ) {
            Group {
                imageComponent()
                    .scaledToFill()
                    .foregroundColor(.Foreground100)
                    .layoutPriority(3)
                
                configuration.label
                    .lineLimit(1)
                    .scaledToFill()
                    .font(.paragraph500)
                    .foregroundColor(.Foreground100)
                    .layoutPriority(5)
                
                if !layoutBreakCondition {
                    Spacer()
                }
                
                if let tag {
                    tag
                        .saturation(isEnabled ? 1 : 0)
                        .layoutPriority(3)
                } else if showChevron {
                    Image.Bold.chevronRight
                        .foregroundColor(.Foreground200)
                } else if !layoutBreakCondition {
                    Spacer()
                        .layoutPriority(3)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isEnabled ? 1 : 0.5)
        .padding(.vertical, Spacing.xs * scale)
        .padding(.leading, Spacing.xs * scale)
        .padding(.trailing, Spacing.l * scale)
        .backport
        .background { (isPressedOverride ?? configuration.isPressed) ? Color.Overgray010 : Color.Overgray002 }
        .cornerRadius(Radius.xs * scale)
    }

    @ViewBuilder
    func imageComponent() -> some View {
        imageContent(scale)
            .frame(maxWidth: 40 * scale, maxHeight: 40 * scale)
            .aspectRatio(contentMode: .fit)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .cornerRadius(Radius.xxs * scale)
    }
}

#if DEBUG
    public struct W3MListSelectStylePreviewView: View {
        public init() {}
        
        public var body: some View {
            ScrollView {
                VStack {
                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MListSelectStyle(
                        imageContent: { _ in Image.mockWallet.resizable() },
                        tag: W3MTag(title: "QR CODE", variant: .main)
                    ))

                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MListSelectStyle(
                        imageContent: { scale in
                            ZStack {
                                Color.Overgray005
                                RoundedRectangle(cornerRadius: Radius.xxxs * scale).stroke(.Overgray010, lineWidth: 1 * scale)
                                Image.Medium.wallet
                            }
                        },
                        tag: W3MTag(title: "INSTALLED", variant: .success),
                        isPressedOverride: true
                    ))

                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MListSelectStyle(
                        imageContent: { _ in Image.mockWallet.resizable() }
                    ))

                    Button(action: {}, label: {
                        Text("All wallets")
                    })
                    .buttonStyle(W3MListSelectStyle(
                        imageContent: { _ in
                            Image.optionAll
                        }
                    ))

                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MListSelectStyle(
                        imageContent: { _ in Image.mockWallet.resizable() },
                        tag: W3MTag(title: "QR CODE", variant: .main)
                    ))
                    .disabled(true)
                    
                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MListSelectStyle(
                        imageContent: { _ in Image.mockWallet.resizable() },
                        showChevron: true
                    ))
                    
                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MListSelectStyle(
                        imageContent: { _ in Image.mockWallet.resizable() },
                        showChevron: true
                    ))
                    .disabled(true)
                }
                .padding()
                .background(Color.Overgray002)
            }
        }
    }

    struct W3MListSelect_Preview: PreviewProvider {
        static var previews: some View {
            W3MListSelectStylePreviewView()
                .previewLayout(.sizeThatFits)
        }
    }

#endif
