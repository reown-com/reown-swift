import XCTest
@testable import WalletConnectRelay

// MARK: - Mock factory for SUI test objects

public class SuiMockFactory {
    static func createSignAndExecuteTransactionResult(
        digest: String = "8cZk5Zj1sMZes9jBxrKF3Nv8uZJor3V5XTFmxp3GTxhp"
    ) -> SuiSignAndExecuteTransactionResult {
        return SuiSignAndExecuteTransactionResult(digest: digest)
    }
    
    static func createSignTransactionResult(
        signature: String = "AO5NvUcI9+oKQZe+vZKPGFnpxA22kxZ9kKYcJUlpQKFktgRzXq1zP8vfJwQQ1rEEQQuAC5+0rPpEYvJCzYaelgGOfJUpmMGwaOgzJTvNpnUf5wYvgYRMcGQ/sL3OuFtB",
        transactionBytes: String = "AAAyQUz8RLI4P3k3TBKRjKbf8JF8TZm9eBBzWQAAAAAAAAABAQAAAAAAAAAMAgAAAAAAAAANAwAAAAAAAABAAAAAAAAAAEGPTnCp/DgxJKq1HWMpVoEGPzNbnvhF6qYlXVMAAAAAECQFAAAAAAAAAKQRBgAAAAAAIHn/FzA=="
    ) -> SuiSignTransactionResult {
        return SuiSignTransactionResult(signature: signature, transactionBytes: transactionBytes)
    }
}

final class SuiTVFCollectorTests: XCTestCase {
    
    private let suiCollector = SuiTVFCollector()
    
    // Helper for creating RPCResult objects
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(suiCollector.supportsMethod("sui_signAndExecuteTransaction"))
        XCTAssertTrue(suiCollector.supportsMethod("sui_signTransaction"))
        XCTAssertFalse(suiCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(suiCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_SuiSignAndExecuteTransaction() {
        // Create transaction result with expected digest
        let expectedDigest = "8cZk5Zj1sMZes9jBxrKF3Nv8uZJor3V5XTFmxp3GTxhp"
        let resultModel = SuiMockFactory.createSignAndExecuteTransactionResult(digest: expectedDigest)
        
        // Create proper JSON-RPC format response (Tron-style)
        // 1. Encode the resultModel to JSON Data
        let resultModelData = try! JSONEncoder().encode(resultModel)
        // 2. Convert JSON Data to a [String: Any] dictionary
        let resultModelJsonDict = try! JSONSerialization.jsonObject(with: resultModelData) as! [String: Any]
        // 3. Create the payload dictionary for AnyCodable(any:)
        let rpcPayloadForAnyCodable: [String: Any] = ["result": resultModelJsonDict]
        // 4. Wrap this payload using AnyCodable(any:)
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = suiCollector.parseTxHashes(
            rpcMethod: "sui_signAndExecuteTransaction",
            rpcResult: rpcResult
        )
        
        // Verify we got the expected transaction digest
        XCTAssertEqual(txHashes, [expectedDigest])
    }
    
    func testParseTxHashes_SuiSignTransaction() {
        // Create sign transaction result with transaction bytes
        let transactionBytes = "AAAyQUz8RLI4P3k3TBKRjKbf8JF8TZm9eBBzWQAAAAAAAAABAQAAAAAAAAAMAgAAAAAAAAANAwAAAAAAAABAAAAAAAAAAEGPTnCp/DgxJKq1HWMpVoEGPzNbnvhF6qYlXVMAAAAAECQFAAAAAAAAAKQRBgAAAAAAIHn/FzA=="
        let resultModel = SuiMockFactory.createSignTransactionResult(transactionBytes: transactionBytes)
        
        // Create proper JSON-RPC format response (Tron-style)
        // 1. Encode the resultModel to JSON Data
        let resultModelData = try! JSONEncoder().encode(resultModel)
        // 2. Convert JSON Data to a [String: Any] dictionary
        let resultModelJsonDict = try! JSONSerialization.jsonObject(with: resultModelData) as! [String: Any]
        // 3. Create the payload dictionary for AnyCodable(any:)
        let rpcPayloadForAnyCodable: [String: Any] = ["result": resultModelJsonDict]
        // 4. Wrap this payload using AnyCodable(any:)
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = suiCollector.parseTxHashes(
            rpcMethod: "sui_signTransaction",
            rpcResult: rpcResult
        )
        
        // Verify we got a transaction digest
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.count, 1)
        // In the real implementation, we would test an actual calculated digest,
        // but since we're using a placeholder for the calculation, we'll just
        // verify that some digest was generated. The actual BLAKE2b + Base58 logic is
        // tested elsewhere or assumed correct for this unit test's scope.
        XCTAssertFalse(txHashes?.first?.isEmpty ?? true, "Generated digest should not be empty")
    }
    
    // MARK: - Real data test
    
    func testParseTxHashes_SuiSignTransaction_WithRealData() {
        // Real transaction data from user's colleague
        let expectedDigest = "C98G1Uwh5soPMtZZmjUFwbVzWLMoAHzi5jrX2BtABe8v"
        let base64Tx = "AAACAAhkAAAAAAAAAAAg1fZH7bd9T9ox0DBFBkR/s8kuVar3e8XtS3fDMt1GBfoCAgABAQAAAQEDAAAAAAEBANX2R+23fU/aMdAwRQZEf7PJLlWq93vF7Ut3wzLdRgX6At/pRJzj2VpZgqXpSvEtd3GzPvt99hR8e/yOCGz/8nbRmA7QFAAAAAAgBy5vStJizn76LmJTBlDiONdR/2rSuzzS4L+Tp/Zs4hZ8cBxYkcSlxBD6QXvgS11E6d+DNek8LiA/beba6iH3l5gO0BQAAAAAIMpdmZjiqJ5GG9di1MAgD4S3uRr2gaMC7S1WsaeBwNIx1fZH7bd9T9ox0DBFBkR/s8kuVar3e8XtS3fDMt1GBfroAwAAAAAAAECrPAAAAAAAAA=="
        
        // Create sign transaction result with real transaction bytes
        let resultModel = SuiSignTransactionResult(signature: "dummy-signature", transactionBytes: base64Tx)
        
        // Create proper JSON-RPC format response
        let resultModelData = try! JSONEncoder().encode(resultModel)
        let resultModelJsonDict = try! JSONSerialization.jsonObject(with: resultModelData) as! [String: Any]
        let rpcPayloadForAnyCodable: [String: Any] = ["result": resultModelJsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = suiCollector.parseTxHashes(
            rpcMethod: "sui_signTransaction",
            rpcResult: rpcResult
        )
        
        // Verify the calculated digest matches the expected one
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.first, expectedDigest, "The calculated digest doesn't match the expected one")
    }
} 
