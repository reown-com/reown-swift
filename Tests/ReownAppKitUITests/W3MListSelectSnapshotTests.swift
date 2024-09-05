import SnapshotTesting
import SwiftUI
@testable import ReownAppKitUI
import XCTest

final class W3MListSelectSnapshotTests: XCTestCase {
    func test_snapshots() throws {
        let view = W3MListSelectStylePreviewView()
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .dark)))
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .light)))
        
        assertSnapshot(
            matching: view,
            as: .image(
                layout: .device(config: .iPhone13),
                traits: UITraitCollection(
                    traitsFrom: [
                        .init(userInterfaceStyle: .dark),
                        .init(preferredContentSizeCategory: .accessibilityExtraExtraLarge)
                    ]
                )
            )
        )
    }
}
