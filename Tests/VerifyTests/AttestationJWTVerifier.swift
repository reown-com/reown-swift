import XCTest
import CryptoKit
@testable import WalletConnectVerify

class AttestationJWTVerifierTests: XCTestCase {
    var verifier: AttestationJWTVerifier!
    var mockManager: VerifyServerPubKeyManagerMock!

    // The signed test attestation below carries exp = 1723471723.
    private let testJWT = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MjM0NzE3MjMsImlkIjoiYjNmYmZhMDUxZDJhNjdkNGRmNTYzM2IyMjc0NDAyNTUxMTg1NzQwZGQwMjA3YWM0OWI1M2RiYTcxOTc0YTgzNCIsIm9yaWdpbiI6Imh0dHBzOi8vcmVhY3QtZGFwcC12Mi1naXQtY2hvcmUtdmVyaWZ5LXYyLXNhbXBsZXMtd2FsbGV0Y29ubmVjdDEudmVyY2VsLmFwcCIsImlzU2NhbSI6bnVsbCwiaXNWZXJpZmllZCI6dHJ1ZX0.8RQwiEEfTGn8p3INRdHpi88dpzetKCp3nscfLtWG2cVE2dU0dWgV2ncqnh_RWmygqEnWCPUlH1RMwS1nWbZzrQ"
    private let testMessageId = "b3fbfa051d2a67d4df5633b2274402551185740dd0207ac49b53dba71974a834"
    private let testJWTExp: TimeInterval = 1723471723

    override func setUp() {
        super.setUp()
        mockManager = VerifyServerPubKeyManagerMock()
        // Evaluate as of a moment before the attestation's expiry by default.
        verifier = AttestationJWTVerifier(
            verifyServerPubKeyManager: mockManager,
            currentTimeProvider: { Date(timeIntervalSince1970: self.testJWTExp - 60) }
        )
    }

    func testVerifyValidJWT() async throws {
        let response = try await verifier.verify(attestationJWT: testJWT, messageId: testMessageId)
        XCTAssertEqual(response.origin, "https://react-dapp-v2-git-chore-verify-v2-samples-walletconnect1.vercel.app")
    }

    func testVerifyExpiredJWTThrows() async throws {
        // Evaluate as of a moment after the attestation's expiry.
        let expiredVerifier = AttestationJWTVerifier(
            verifyServerPubKeyManager: mockManager,
            currentTimeProvider: { Date(timeIntervalSince1970: self.testJWTExp + 60) }
        )
        do {
            _ = try await expiredVerifier.verify(attestationJWT: testJWT, messageId: testMessageId)
            XCTFail("Expected to throw attestationExpired error")
        } catch AttestationJWTVerifier.Errors.attestationExpired {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testVerifyJWTWithInvalidMessageId() async throws {
        let invalidMessageId = "InvalidMessageId"

        do {
            _ = try await verifier.verify(attestationJWT: testJWT, messageId: invalidMessageId)
            XCTFail("Expected to throw messageIdMismatch error")
        } catch AttestationJWTVerifier.Errors.messageIdMismatch {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
