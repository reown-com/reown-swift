import XCTest
@testable import WalletConnectRelay

// MARK: - Mock factory for NEAR test objects

public class NearMockFactory {
    // Real NEAR transaction data based on the documentation examples
    static func createSignedTransactionData() -> [UInt8] {
        return [
            16, 0, 0, 0, 48, 120, 103, 97, 110, 99, 104, 111, 46, 116, 101, 115, 116, 110, 101, 116,
            0, 243, 74, 204, 31, 29, 80, 146, 149, 102, 175, 8, 83, 231, 187, 5, 120, 41, 115, 247,
            22, 197, 120, 182, 242, 120, 135, 73, 137, 166, 246, 171, 103, 77, 243, 34, 42, 212, 180,
            0, 0, 16, 0, 0, 0, 48, 120, 103, 97, 110, 99, 104, 111, 46, 116, 101, 115, 116, 110, 101, 116,
            5, 233, 95, 227, 45, 10, 101, 176, 111, 124, 190, 86, 106, 27, 143, 54, 148, 125, 132, 252,
            25, 71, 125, 78, 60, 242, 100, 219, 40, 168, 65, 3, 1, 0, 0, 0, 3, 0, 0, 0, 161, 237, 204,
            206, 27, 194, 211, 0, 0, 0, 0, 0, 0
        ]
    }
    
    // Another real transaction for multiple transactions test
    static func createSecondSignedTransactionData() -> [UInt8] {
        return [
            17, 0, 0, 0, 97, 108, 105, 99, 101, 46, 116, 101, 115, 116, 110, 101, 116, 0, 243, 74,
            204, 31, 29, 80, 146, 149, 102, 175, 8, 83, 231, 187, 5, 120, 41, 115, 247, 22, 197,
            120, 182, 242, 120, 135, 73, 137, 166, 246, 171, 103, 77, 243, 34, 42, 212, 180, 0, 0,
            15, 0, 0, 0, 98, 111, 98, 46, 116, 101, 115, 116, 110, 101, 116, 5, 233, 95, 227, 45,
            10, 101, 176, 111, 124, 190, 86, 106, 27, 143, 54, 148, 125, 132, 252, 25, 71, 125, 78,
            60, 242, 100, 219, 40, 168, 65, 3, 1, 0, 0, 0, 3, 0, 0, 0, 161, 237, 204, 206, 27, 194,
            211, 0, 0, 0, 0, 0, 0
        ]
    }
    
    static func createMultipleSignedTransactionData() -> [[UInt8]] {
        return [
            createSignedTransactionData(),
            createSecondSignedTransactionData()
        ]
    }
    
    // Creates a Buffer-style object as mentioned in the docs
    static func createBufferStyleTransactionData() -> [String: Any] {
        return [
            "type": "Buffer",
            "data": createSignedTransactionData()
        ]
    }
    
    // Creates a JSON bytes array object with string keys (another format mentioned in docs)
    static func createJsonBytesArrayTransactionData() -> [String: Any] {
        let bytesArray = createSignedTransactionData()
        var jsonBytesArray: [String: Any] = [:]
        
        for (index, byte) in bytesArray.enumerated() {
            jsonBytesArray[String(index)] = Int(byte)
        }
        
        return jsonBytesArray
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
    
    // MARK: - Contract Address Extraction Tests
    
    func testExtractContractAddresses_ReturnsNil() {
        // NEAR doesn't extract contract addresses for TVF
        let params = AnyCodable([String]())
        let addresses = nearCollector.extractContractAddresses(
            rpcMethod: "near_signTransaction",
            rpcParams: params
        )
        XCTAssertNil(addresses)
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_NearSignTransaction_ValidData_ExtractsHash() {
        // Arrange
        let signedTxData = NearMockFactory.createSignedTransactionData()
        let intArray = signedTxData.map { Int($0) }
        
        // Create proper JSON-RPC format response
        let rpcPayload = ["result": intArray]
        let rpcResult = makeResponse(rpcPayload)
        
        // Act
        let hashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransaction",
            rpcResult: rpcResult
        )
        
        // Assert
        XCTAssertNotNil(hashes)
        XCTAssertEqual(hashes?.count, 1)
        
        // Verify the hash is calculated correctly
        let expectedHash = Base58.encode(Data(signedTxData).sha256())
        XCTAssertEqual(hashes?.first, expectedHash)
    }
    
    func testParseTxHashes_NearSignTransaction_BufferFormat_ExtractsHash() {
        // Arrange
        let bufferData = NearMockFactory.createBufferStyleTransactionData()
        
        // Create proper JSON-RPC format response
        let rpcPayload = ["result": bufferData]
        let rpcResult = makeResponse(rpcPayload)
        
        // Act
        let hashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransaction",
            rpcResult: rpcResult
        )
        
        // Assert
        XCTAssertNotNil(hashes)
        XCTAssertEqual(hashes?.count, 1)
        
        // Verify the hash is calculated correctly
        let originalData = NearMockFactory.createSignedTransactionData()
        let expectedHash = Base58.encode(Data(originalData).sha256())
        XCTAssertEqual(hashes?.first, expectedHash)
    }
    
    func testParseTxHashes_NearSignTransaction_JsonBytesArrayFormat_ExtractsHash() {
        // Arrange
        let jsonBytesData = NearMockFactory.createJsonBytesArrayTransactionData()
        
        // Create proper JSON-RPC format response
        let rpcPayload = ["result": jsonBytesData]
        let rpcResult = makeResponse(rpcPayload)
        
        // Act
        let hashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransaction",
            rpcResult: rpcResult
        )
        
        // Assert
        XCTAssertNotNil(hashes)
        XCTAssertEqual(hashes?.count, 1)
        
        // Verify the hash is calculated correctly - should match the expected hash from docs
        let originalData = NearMockFactory.createSignedTransactionData()
        let expectedHash = Base58.encode(Data(originalData).sha256())
        XCTAssertEqual(hashes?.first, expectedHash)
        
        // Also verify against the specific hash mentioned in the documentation
        XCTAssertEqual(hashes?.first, "EpHx79wKAn6br4G9aKaCGLpdzNc8YjrthiFonXQgskAx")
    }
    
    func testParseTxHashes_NearSignTransactions_ValidData_ExtractsHashes() {
        // Arrange
        let signedTxDataArray = NearMockFactory.createMultipleSignedTransactionData()
        let intArrays = signedTxDataArray.map { uint8Array in
            return uint8Array.map { Int($0) }
        }
        
        // Create proper JSON-RPC format response
        let rpcPayload = ["result": intArrays]
        let rpcResult = makeResponse(rpcPayload)
        
        // Act
        let hashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransactions",
            rpcResult: rpcResult
        )
        
        // Assert
        XCTAssertNotNil(hashes)
        XCTAssertEqual(hashes?.count, 2)
        
        // Verify both hashes are calculated correctly
        let expectedHashes = signedTxDataArray.map { txData in
            Base58.encode(Data(txData).sha256())
        }
        XCTAssertEqual(hashes, expectedHashes)
    }
    
    func testParseTxHashes_UnsupportedMethod_ReturnsNil() {
        // Arrange
        let signedTxData = NearMockFactory.createSignedTransactionData()
        let intArray = signedTxData.map { Int($0) }
        let rpcPayload = ["result": intArray]
        let rpcResult = makeResponse(rpcPayload)
        
        // Act
        let hashes = nearCollector.parseTxHashes(
            rpcMethod: "eth_sendTransaction",
            rpcResult: rpcResult
        )
        
        // Assert
        XCTAssertNil(hashes)
    }
    
    func testParseTxHashes_MalformedData_ReturnsNil() {
        // Arrange - invalid data format
        let rpcPayload = ["result": "invalid_data"]
        let rpcResult = makeResponse(rpcPayload)
        
        // Act
        let hashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransaction",
            rpcResult: rpcResult
        )
        
        // Assert
        XCTAssertNil(hashes)
    }
    
    func testParseTxHashes_NilResult_ReturnsNil() {
        // Act
        let hashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransaction",
            rpcResult: nil
        )
        
        // Assert
        XCTAssertNil(hashes)
    }
    
    func testParseTxHashes_EmptyTransactionArray_ReturnsNil() {
        // Arrange
        let rpcPayload = ["result": []]
        let rpcResult = makeResponse(rpcPayload)
        
        // Act
        let hashes = nearCollector.parseTxHashes(
            rpcMethod: "near_signTransactions",
            rpcResult: rpcResult
        )
        
        // Assert
        XCTAssertNil(hashes)
    }
    
    // MARK: - Real Data Hash Verification Tests
    
    func testHashCalculation_MatchesExpectedFormat() {
        // Test with known data to verify Base58 + SHA256 implementation
        let testData = Data([1, 2, 3, 4, 5])
        let expectedSha256 = testData.sha256()
        let expectedBase58 = Base58.encode(expectedSha256)
        
        // Verify our implementation matches expected format
        XCTAssertFalse(expectedBase58.isEmpty)
        XCTAssertTrue(expectedBase58.allSatisfy { char in
            Base58.baseAlphabets.contains(char)
        })
    }
    
    func testHashCalculation_MatchesDocumentationExample() {
        // Test with the exact data from the documentation to verify we get the expected hash
        let documentationData = NearMockFactory.createSignedTransactionData()
        let hash = Base58.encode(Data(documentationData).sha256())
        
        // This should match the hash specified in the documentation
        XCTAssertEqual(hash, "EpHx79wKAn6br4G9aKaCGLpdzNc8YjrthiFonXQgskAx")
    }
} 
