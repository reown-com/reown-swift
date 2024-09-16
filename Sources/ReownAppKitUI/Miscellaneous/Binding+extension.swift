import SwiftUI

public extension Binding {
    /// Shorthand for default binding. Usually handy in View initialisers where outside binding is optional.
    static func stored(_ value: Value) -> Self {
        var value = value
        return .init(get: { value }, set: { value = $0 })
    }
}
