import XCTest
@testable import WalletConnectRelay

// MARK: - Mock factory for NEAR test objects

public class NearMockFactory {
    // Sample signed transaction data (simplified for testing)
    static func createSignedTransactionData() -> [UInt8] {
        return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    }
    
    static func createMultipleSignedTransactionData() -> [[UInt8]] {
        return [
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
        ]
    }
}

final class NearTVFCollectorTests: XCTestCase {
    
    private let nearCollector = NearTVFCollector()
    
    // Helper for creating RPCResult objects
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(nearCollector.supportsMethod("near_signTransaction"))
        XCTAssertTrue(nearCollector.supportsMethod("near_signTransactions"))
        XCTAssertFalse(nearCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(nearCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_NearSignTransaction_ArrayFormat() {
        // Create signed transaction data as array of integers
        let signedTxData = NearMockFactory.createSignedTransactionData()
        
        // Convert UInt8 array to Int array for proper JSON serialization
        let intArray = signedTxData.map { Int($0) }
        
        // Create proper JSON-RPC format response using the Tron approach (serialize/deserialize)
        // This ensures the payload structure can be properly handled by AnyCodable
        let jsonData = try! JSONSerialization.data(withJSONObject: intArray)
        let jsonArray = try! JSONSerialization.jsonObject(with: jsonData)
        let rpcPayloadForAnyCodable: [String: Any] = ["result": jsonArray]
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransaction",
            rpcResult: rpcResult
        )
        
        // Verify we got a transaction hash
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.count, 1)
        
        // Check hash format (Base58 encoded)
        let expectedHash = Base58.encode(Data(signedTxData))
        XCTAssertEqual(txHashes?.first, expectedHash)
    }
    
    func testParseTxHashes_NearSignTransaction_DictionaryFormat() {
        // Create dictionary format that might be received from JS
        let signedTxData = NearMockFactory.createSignedTransactionData()
        var dictData: [String: Int] = [:]
        for (index, value) in signedTxData.enumerated() {
            dictData[String(index)] = Int(value)
        }
        
        // Create proper JSON-RPC format response with serialization/deserialization
        let jsonData = try! JSONSerialization.data(withJSONObject: dictData)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData)
        let rpcPayloadForAnyCodable: [String: Any] = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransaction",
            rpcResult: rpcResult
        )
        
        // Verify we got a transaction hash
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.count, 1)
        
        // Check hash format (Base58 encoded)
        let expectedHash = Base58.encode(Data(signedTxData))
        XCTAssertEqual(txHashes?.first, expectedHash)
    }
    
    func testParseTxHashes_NearSignTransactions() {
        // Create multiple signed transaction data
        let signedTxDataArray = NearMockFactory.createMultipleSignedTransactionData()
        
        // Convert nested UInt8 arrays to Int arrays for proper JSON serialization
        let intArrays = signedTxDataArray.map { uint8Array in
            return uint8Array.map { Int($0) }
        }
        
        // Create proper JSON-RPC format response with serialization/deserialization
        let jsonData = try! JSONSerialization.data(withJSONObject: intArrays)
        let jsonArrays = try! JSONSerialization.jsonObject(with: jsonData)
        let rpcPayloadForAnyCodable: [String: Any] = ["result": jsonArrays]
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Test hash extraction
        let txHashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransactions",
            rpcResult: rpcResult
        )
        
        // Verify we got transaction hashes
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.count, 2)
        
        // Check hash formats (Base58 encoded)
        let expectedHashes = signedTxDataArray.map { Base58.encode(Data($0)) }
        XCTAssertEqual(txHashes, expectedHashes)
    }

} 
