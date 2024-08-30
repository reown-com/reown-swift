import SnapshotTesting
import SwiftUI
@testable import ReownAppKitUI
import XCTest

final class W3MCardSelectSnapshotTests: XCTestCase {
    
    func test_snapshots() throws {
        let view = W3MCardSelectStylePreviewView()
        assertSnapshot(matching: view, as: .image(traits: .init(userInterfaceStyle: .dark)))
        assertSnapshot(matching: view, as: .image(traits: .init(userInterfaceStyle: .light)))
    }
}
