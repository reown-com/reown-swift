import SnapshotTesting
import SwiftUI
@testable import Web3ModalUI
import XCTest

final class W3MListItemSnapshotTests: XCTestCase {
    func test_snapshots() throws {
        let view = W3MListItemButtonStylePreviewView()

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
