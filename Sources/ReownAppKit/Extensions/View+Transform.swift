import SwiftUI

#if !CocoaPods
extension View {
    /// Transforms the source `View` with the given closure.
    func transform(@ViewBuilder _ transform: (Self) -> some View) -> some View {
        transform(self)
    }
}
#endif
