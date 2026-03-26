import XCTest
@testable import WalletConnectRelay

// MARK: - Mock factory for Bitcoin test objects

public class BitcoinMockFactory {
    static func createTransferResult(
        txid: String = "f007551f169722ce74104d6673bd46ce193c624b8550889526d1b93820d725f7"
    ) -> BitcoinTransferResult {
        return BitcoinTransferResult(txid: txid)
    }
}

final class BitcoinTVFCollectorTests: XCTestCase {
    
    private let bitcoinCollector = BitcoinTVFCollector()
    
    // Helper for creating RPCResult objects
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(bitcoinCollector.supportsMethod("sendTransfer"))
        XCTAssertFalse(bitcoinCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(bitcoinCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_SendTransfer() {
        // Create transfer result with expected txid
        let expectedTxid = "f007551f169722ce74104d6673bd46ce193c624b8550889526d1b93820d725f7"
        let resultModel = BitcoinMockFactory.createTransferResult(txid: expectedTxid)
        
        // Create proper JSON-RPC format response (using serialization/deserialization for JSON compatibility)
        let resultModelData = try! JSONEncoder().encode(resultModel)
        let resultModelJsonDict = try! JSONSerialization.jsonObject(with: resultModelData) as! [String: Any]
        let rpcPayloadForAnyCodable: [String: Any] = ["result": resultModelJsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = bitcoinCollector.parseTxHashes(
            rpcMethod: "sendTransfer",
            rpcResult: rpcResult
        )
        
        // Verify we got the expected transaction hash
        XCTAssertEqual(txHashes, [expectedTxid])
    }
}
