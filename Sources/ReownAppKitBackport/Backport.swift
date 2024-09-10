import SwiftUI

public struct Backport<Wrapped> {
    let wrapped: Wrapped

    public init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
    }
}

public extension View {
    /// Wraps a SwiftUI `View` that can be extended to provide backport functionality.
    var backport: Backport<Self> { .init(self) }
}
