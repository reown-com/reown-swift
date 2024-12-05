import SwiftUI
import UIKit

public struct ShimmerBackground: ViewModifier {
    private let animation: Animation
    private let gradient: Gradient
    private let min, max: CGFloat
    @State private var isInitialState = true
    @Environment(\.layoutDirection) private var layoutDirection

    /// Initializes his modifier with a custom animation,
    /// - Parameters:
    ///   - animation: A custom animation. Defaults to ``Shimmer/defaultAnimation``.
    ///   - gradient: A custom gradient. Defaults to ``Shimmer/defaultGradient``.
    ///   - bandSize: The size of the animated mask's "band". Defaults to 0.3 unit points, which corresponds to
    /// 30% of the extent of the gradient.
    public init(
        animation: Animation = Self.defaultAnimation,
        gradient: Gradient = Self.defaultGradient,
        bandSize: CGFloat = 0.3
    ) {
        self.animation = animation
        self.gradient = gradient
        // Calculate unit point dimensions beyond the gradient's edges by the band size
        self.min = 0 - bandSize
        self.max = 1 + bandSize
    }

    /// The default animation effect.
    public static let defaultAnimation = Animation.linear(duration: 0.5).delay(0.25).repeatForever(autoreverses: false)

    // A default gradient for the animated mask.
    public static let defaultGradient = Gradient(colors: [
        .black.opacity(0.3), // translucent
        .black, // opaque
        .black.opacity(0.3) // translucent
    ])

    /// The start unit point of our gradient, adjusting for layout direction.
    var startPoint: UnitPoint {
        return isInitialState ? UnitPoint(x: min, y: min) : UnitPoint(x: 1, y: 1)
    }

    /// The end unit point of our gradient, adjusting for layout direction.
    var endPoint: UnitPoint {
        return isInitialState ? UnitPoint(x: 0, y: 0) : UnitPoint(x: max, y: max)
    }

    public func body(content: Content) -> some View {
        content
            .mask(LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint))
            .onAppear {
                withAnimation(animation) {
                    isInitialState = false
                }
            }
    }
}

struct Shimmer_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            RoundedRectangle(cornerRadius: Radius.xs)
                .stroke(.Overgray010, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: Radius.xs).fill(.red))
                .frame(width: 100, height: 100)
                .modifier(ShimmerBackground())
            
            RoundedRectangle(cornerRadius: Radius.xs)
                .stroke(.Overgray010, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: Radius.xs).fill(.Overgray005))
                .frame(width: 100, height: 100)
                .modifier(ShimmerBackground())
        }
    }
}
