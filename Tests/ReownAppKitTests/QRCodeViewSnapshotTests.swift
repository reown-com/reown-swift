import SnapshotTesting
import SwiftUI
@testable import ReownAppKit
import XCTest

final class QRCodeViewSnapshotTests: XCTestCase {
    
    func test_snapshots() throws {
        let view = QRCodeViewPreviewView()
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .dark)))
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .light)))
    }
}
