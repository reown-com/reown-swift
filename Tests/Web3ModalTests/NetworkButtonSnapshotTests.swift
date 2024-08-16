import SnapshotTesting
import SwiftUI
@testable import Web3Modal
import XCTest

final class NetworkButtonSnapshotTests: XCTestCase {
    
    func test_snapshots() throws {
        let view = NetworkButtonPreviewView()
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .dark)))
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13), traits: .init(userInterfaceStyle: .light)))
    }
}
