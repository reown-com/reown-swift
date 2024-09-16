import SwiftUI

extension Backport where Wrapped: View {
    public func background<Content: View>(alignment: Alignment = .center, @ViewBuilder _ content: () -> Content) -> some View {
        wrapped.background(content(), alignment: alignment)
    }
}
