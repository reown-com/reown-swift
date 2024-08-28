import SwiftUI

public struct W3MCardSelectStyle<ImageContent: View>: ButtonStyle {
    public enum Variant {
        case wallet
        case network
    }

    @Environment(\.isEnabled) var isEnabled

    let variant: Variant

    var imageContent: () -> ImageContent
    var isPressedOverride: Bool?
    var isSelected: Bool
    
    @Binding var isLoading: Bool

    public init(
        variant: Variant,
        @ViewBuilder imageContent: @escaping () -> ImageContent,
        isLoading: Binding<Bool> = .constant(false),
        isSelected: Bool = false
    ) {
        self.variant = variant
        self.imageContent = imageContent
        self._isLoading = isLoading
        self.isSelected = isSelected
    }

    #if DEBUG
        init(
            variant: Variant,
            @ViewBuilder imageContent: @escaping () -> ImageContent,
            isPressedOverride: Bool? = nil,
            isLoading: Binding<Bool>,
            isSelected: Bool = false
        ) {
            self.variant = variant
            self.imageContent = imageContent
            self.isPressedOverride = isPressedOverride
            self._isLoading = isLoading
            self.isSelected = isSelected
        }
    #endif

    public func makeBody(configuration: Configuration) -> some View {
        
        var backgroundColor: Color = (isPressedOverride ?? configuration.isPressed) ? .Overgray010 : .Overgray005
        backgroundColor = isSelected ? Color.Blue100.opacity(0.2) : backgroundColor
        
        var foregroundColor: Color = .Foreground100
        foregroundColor = isSelected ? .Blue100 : foregroundColor
        
        return VStack(spacing: Spacing.xs) {
            imageComponent()

            configuration.label
                .font(.tiny500)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .opacity(isLoading ? 0 : 1)
                .backport
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .stroke(.Overgray010, lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: Radius.xs).fill(.Overgray005))
                        .opacity(isLoading ? 1 : 0)
                }
                .padding(.horizontal, Spacing.xs)
        }
        .if(isLoading) {
            $0.modifier(ShimmerBackground())
        }
        .opacity(isEnabled || isSelected ? 1 : 0.5)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xxs)
        .background(backgroundColor)
        .cornerRadius(Radius.xs)
        .frame(minWidth: 76, maxWidth: 76, minHeight: 96, maxHeight: 96)
    }

    @ViewBuilder
    func imageComponent() -> some View {
        imageContent()
            .frame(width: 56, height: 56)
            .saturation(isEnabled || isSelected ? 1 : 0)
            .opacity(isEnabled || isSelected ? 1 : 0.5)
            .transform {
                switch variant {
                case .network:
                    $0.clipShape(Polygon(count: 6, relativeCornerRadius: 0.25))
                case .wallet:
                    $0.clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                }
            }
            .backport
            .overlay {
                switch variant {
                case .network:
                    Polygon(count: 6, relativeCornerRadius: 0.25)
                        .stroke(isSelected ? .Blue100 : .Overgray010, lineWidth: 1)
                        .background(Polygon(count: 6, relativeCornerRadius: 0.25).fill(.Overgray005).opacity(isLoading ? 1 : 0))
                case .wallet:
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .strokeBorder(isSelected ? .Blue100 : .Overgray010, lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: Radius.xs).fill(.Overgray005).opacity(isLoading ? 1 : 0))
                }
            }
    }
}

#if DEBUG
    public struct W3MCardSelectStylePreviewView: View {
        public init() {}

        public var body: some View {
            VStack {
                HStack {
                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .wallet,
                        imageContent: { Image.mockWallet.resizable() },
                        isLoading: .constant(false)
                    ))

                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .wallet,
                        imageContent: { Image.mockWallet.resizable() },
                        isLoading: .constant(false)
                    ))
                    .disabled(true)

                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .wallet,
                        imageContent: { Image.mockWallet.resizable() },
                        isLoading: .constant(false),
                        isSelected: true
                    ))
                    
                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .wallet,
                        imageContent: { Image.mockWallet.resizable() },
                        isPressedOverride: true,
                        isLoading: .constant(false)
                    ))

                    Button(action: {}, label: {
                        Text("Rainbow")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .wallet,
                        imageContent: { Color.Overgray005 },
                        isPressedOverride: false,
                        isLoading: .constant(true)
                    ))
                }

                HStack {
                    Button(action: {}, label: {
                        Text("Polygon")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .network,
                        imageContent: { Image("MockChainImage", bundle: .module).resizable() },
                        isLoading: .constant(false)
                    ))
                    Button(action: {}, label: {
                        Text("Polygon")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .network,
                        imageContent: { Image("MockChainImage", bundle: .module).resizable() },
                        isLoading: .constant(false)
                    ))
                    .disabled(true)
                    
                    Button(action: {}, label: {
                        Text("Polygon")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .network,
                        imageContent: { Image("MockChainImage", bundle: .module).resizable() },
                        isLoading: .constant(false),
                        isSelected: true
                    ))

                    Button(action: {}, label: {
                        Text("Polygon")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .network,
                        imageContent: { Image("MockChainImage", bundle: .module).resizable() },
                        isPressedOverride: true,
                        isLoading: .constant(false)
                    ))

                    Button(action: {}, label: {
                        Text("Polygon")
                    })
                    .buttonStyle(W3MCardSelectStyle(
                        variant: .network,
                        imageContent: { Color.Overgray005 },
                        isPressedOverride: false,
                        isLoading: .constant(true)
                    ))
                }
            }
            .padding()
            .background(Color.Overgray002)
        }
    }

    struct W3MCardSelect_Preview: PreviewProvider {
        static var previews: some View {
            W3MCardSelectStylePreviewView()
                .previewLayout(.sizeThatFits)
        }
    }

#endif
