import SnapshotTesting
import SwiftUI
@testable import ReownAppKitUI
import XCTest

final class W3MChipButtonSnapshotTests: XCTestCase {
    
    func test_snapshots() throws {
        let view = W3MChipButtonStylePreviewView()
        assertSnapshot(matching: view, as: .image(layout: .fixed(width: 800, height: 800), traits: .init(userInterfaceStyle: .dark)))
        assertSnapshot(matching: view, as: .image(layout: .fixed(width: 800, height: 800), traits: .init(userInterfaceStyle: .light)))
    }
}
