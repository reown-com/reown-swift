import XCTest
@testable import WalletConnectUtils

class SolanaSignatureExtractorTests: XCTestCase {

    func testExtractSignatureFromTransaction() throws {
        // The Base64-encoded transaction provided in the query
        let base64Transaction = "AYxQUCwuEoBMHp45bxp9yyegtoVUcyyc0idYrBan1PW/mWWA4MrXsbytuJt9FP1tXH5ZxYYyKc3YmBM+hcueqA4BAAIDb3ObYkq6BFd46JrMFy1h0Q+dGmyRGtpelqTKkIg82isAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMGRm/lIRcy/+ytunLDm+e8jOW7xfcSayxDmzpAAAAAanHwLXEo8xArFhOhqld18H+7VdHJSIY4f27y1qCK4AoDAgAFAlgCAAABAgAADAIAAACghgEAAAAAAAIACQMgTgAAAAAAAA=="

        let signature = try SolanaSignatureExtractor.extractSignature(from: base64Transaction)

        let expectedSignature = "3oi6k2bd1fQdUenuMSeP3Zr18a3iRMuFcbgTnehBrQZP6nftmsVqMi1np4ENJr5HmuSgSsejfUYYpqTCXhnadSjw"

        // Verify the result
        XCTAssertEqual(signature, expectedSignature, "Extracted signature should match the expected Base58 signature from the provided transaction.")
    }
}
