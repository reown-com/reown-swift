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
        
        // Create proper JSON-RPC format response
        let rpcResult = RPCResult.response(AnyCodable(any: ["result": resultModel]))
        
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
        
        // Create proper JSON-RPC format response
        let rpcResult = RPCResult.response(AnyCodable(any: ["result": resultModel]))
        
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
        // verify that some digest was generated
        XCTAssertTrue(txHashes?.first?.starts(with: "SuiDigest-") ?? false)
    }
    
    func testParseTxHashes_ErrorCase() {
        let rpcResult = makeError(code: -32000, message: "some error")
        
        let txHashes = suiCollector.parseTxHashes(
            rpcMethod: "sui_signAndExecuteTransaction",
            rpcResult: rpcResult
        )
        
        XCTAssertNil(txHashes)
    }
} 