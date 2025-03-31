import XCTest
@testable import WalletConnectPairing

final class AppMetadataTests: XCTestCase {
    
    func testDecodingWithMissingUrlProperty() throws {
        let json = """
        {
            "name": "Test App",
            "description": "Test Description",
            "icons": ["https://test.com/icon.png"]
        }
        """.data(using: .utf8)!
        
        let metadata = try JSONDecoder().decode(AppMetadata.self, from: json)
        XCTAssertEqual(metadata.url, "")
    }
    
    func testDecodingWithPresentUrlProperty() throws {
        let json = """
        {
            "name": "Test App",
            "description": "Test Description",
            "url": "https://test.com",
            "icons": ["https://test.com/icon.png"]
        }
        """.data(using: .utf8)!
        
        let metadata = try JSONDecoder().decode(AppMetadata.self, from: json)
        XCTAssertEqual(metadata.url, "https://test.com")
    }
}

final class RedirectTests: XCTestCase {

    func testInitThrowsErrorWhenLinkModeIsTrueAndUniversalIsNil() {
        XCTAssertThrowsError(try AppMetadata.Redirect(native: "nativeURL", universal: nil, linkMode: true)) { error in
            XCTAssertEqual(error as? AppMetadata.Redirect.Errors, .invalidLinkModeUniversalLink)
        }
    }

    func testInitThrowsErrorWhenUniversalIsInvalidURL() {
        XCTAssertThrowsError(try AppMetadata.Redirect(native: "nativeURL", universal: "invalid-url", linkMode: false)) { error in
            XCTAssertEqual(error as? AppMetadata.Redirect.Errors, .invalidUniversalLinkURL)
        }
    }

    func testInitSucceedsWhenUniversalIsValidURLAndLinkModeIsTrue() {
        XCTAssertNoThrow(try AppMetadata.Redirect(native: "nativeURL", universal: "https://valid.url", linkMode: true))
    }

    func testInitSucceedsWhenUniversalIsValidURLAndLinkModeIsFalse() {
        XCTAssertNoThrow(try AppMetadata.Redirect(native: "nativeURL", universal: "https://valid.url", linkMode: false))
    }

    func testInitSucceedsWhenUniversalIsValidURLWithWWWAndLinkModeIsFalse() {
        XCTAssertNoThrow(try AppMetadata.Redirect(native: "nativeURL", universal: "www.valid.com", linkMode: false))
    }

    func testInitSucceedsWhenLinkModeIsFalseAndUniversalIsNil() {
        XCTAssertNoThrow(try AppMetadata.Redirect(native: "nativeURL", universal: nil, linkMode: false))
    }
}
