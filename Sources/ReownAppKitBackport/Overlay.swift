import SwiftUI

extension Backport where Wrapped: View {
    public func overlay<Content: View>(alignment: Alignment = .center, @ViewBuilder _ content: () -> Content) -> some View {
        self.wrapped.overlay(content(), alignment: alignment)
    }
}
