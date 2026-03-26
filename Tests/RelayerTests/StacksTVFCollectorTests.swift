import XCTest
@testable import WalletConnectRelay

// MARK: - Mock factory for Stacks test objects

public class StacksMockFactory {
    static func createTransferResult(
        txid: String = "stack_tx_id",
        transaction: String = "raw_tx_hex"
    ) -> StacksTransferResult {
        return StacksTransferResult(txid: txid, transaction: transaction)
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
        XCTAssertTrue(stacksCollector.supportsMethod("stx_transferStx"))
        XCTAssertFalse(stacksCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(stacksCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_StxTransferStx() {
        // Create transfer result with expected txid
        let expectedTxid = "stack_tx_id"
        let resultModel = StacksMockFactory.createTransferResult(txid: expectedTxid)
        
        // Create proper JSON-RPC format response (using serialization/deserialization for JSON compatibility)
        let resultModelData = try! JSONEncoder().encode(resultModel)
        let resultModelJsonDict = try! JSONSerialization.jsonObject(with: resultModelData) as! [String: Any]
        let rpcPayloadForAnyCodable: [String: Any] = ["result": resultModelJsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = stacksCollector.parseTxHashes(
            rpcMethod: "stx_transferStx",
            rpcResult: rpcResult
        )
        
        // Verify we got the expected transaction hash
        XCTAssertEqual(txHashes, [expectedTxid])
    }
} 