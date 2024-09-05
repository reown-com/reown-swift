import SnapshotTesting
import SwiftUI
@testable import ReownAppKitUI
import XCTest

final class W3MToastSnapshotTests: XCTestCase {
    
    func test_snapshots() throws {
        let view = ToastViewPreviewView()
        assertSnapshot(matching: view, as: .image(layout: .fixed(width: 250, height: 250), traits: .init(userInterfaceStyle: .dark)))
        assertSnapshot(matching: view, as: .image(layout: .fixed(width: 250, height: 250), traits: .init(userInterfaceStyle: .light)))
    }
}
