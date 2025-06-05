import XCTest
@testable import WalletConnectRelay

// MARK: - Mock factory for Stacks test objects

public class StacksMockFactory {
    static func createTransferResult(
        txId: String = "stack_tx_id",
        txRaw: String = "raw_tx_hex"
    ) -> StacksTransferResult {
        return StacksTransferResult(txId: txId, txRaw: txRaw)
    }
}

final class StacksTVFCollectorTests: XCTestCase {
    
    private let stacksCollector = StacksTVFCollector()
    
    // Helper for creating RPCResult objects
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(stacksCollector.supportsMethod("stacks_stxTransfer"))
        XCTAssertFalse(stacksCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(stacksCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_StacksStxTransfer() {
        // Create transfer result with expected txId
        let expectedTxId = "stack_tx_id"
        let resultModel = StacksMockFactory.createTransferResult(txId: expectedTxId)
        
        // Create proper JSON-RPC format response (using serialization/deserialization for JSON compatibility)
        let resultModelData = try! JSONEncoder().encode(resultModel)
        let resultModelJsonDict = try! JSONSerialization.jsonObject(with: resultModelData) as! [String: Any]
        let rpcPayloadForAnyCodable: [String: Any] = ["result": resultModelJsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = stacksCollector.parseTxHashes(
            rpcMethod: "stacks_stxTransfer",
            rpcResult: rpcResult
        )
        
        // Verify we got the expected transaction hash
        XCTAssertEqual(txHashes, [expectedTxId])
    }
} 