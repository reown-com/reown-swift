import SwiftUI

struct AdaptiveStack<Content: View>: View {
    let horizontalAlignment: HorizontalAlignment
    let verticalAlignment: VerticalAlignment
    let spacing: CGFloat?
    let content: () -> Content
    let condition: () -> Bool

    init(
        condition: @autoclosure @escaping () -> Bool,
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.condition = condition
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if condition() {
            VStack(
                alignment: horizontalAlignment,
                spacing: spacing,
                content: content
            )
        } else {
            HStack(
                alignment: verticalAlignment,
                spacing: spacing,
                content: content
            )
        }
    }
}
