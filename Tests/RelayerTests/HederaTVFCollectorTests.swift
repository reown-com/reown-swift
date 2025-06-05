import XCTest
@testable import WalletConnectRelay

// MARK: - Mock factory for Hedera test objects

public class HederaMockFactory {
    static func createTransactionResult(
        nodeId: String = "0.0.3",
        transactionHash: String = "252b8fd7eb3f3e6c15b0ca842d7b5c055c786583bcc7dbf10926727b9107e5bc",
        transactionId: String = "0.0.12345678@1689281510.675369303"
    ) -> HederaTransactionResult {
        return HederaTransactionResult(
            nodeId: nodeId,
            transactionHash: transactionHash,
            transactionId: transactionId
        )
    }
}

final class HederaTVFCollectorTests: XCTestCase {
    
    private let hederaCollector = HederaTVFCollector()
    
    // Helper for creating RPCResult objects
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(hederaCollector.supportsMethod("hedera_signAndExecuteTransaction"))
        XCTAssertTrue(hederaCollector.supportsMethod("hedera_executeTransaction"))
        XCTAssertFalse(hederaCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(hederaCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Contract Address Tests
    
    func testExtractContractAddresses_ReturnsNil() {
        // Hedera doesn't collect contract addresses for TVF
        let rpcParams = AnyCodable("any_params")
        
        let contractAddresses = hederaCollector.extractContractAddresses(
            rpcMethod: "hedera_signAndExecuteTransaction",
            rpcParams: rpcParams
        )
        
        XCTAssertNil(contractAddresses)
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_HederaSignAndExecuteTransaction() {
        // Create transaction result with expected transaction ID
        let expectedTransactionId = "0.0.12345678@1689281510.675369303"
        let resultModel = HederaMockFactory.createTransactionResult(transactionId: expectedTransactionId)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Test hash extraction
        let txHashes = hederaCollector.parseTxHashes(
            rpcMethod: "hedera_signAndExecuteTransaction",
            rpcResult: rpcResult
        )
        
        XCTAssertEqual(txHashes, [expectedTransactionId])
    }
    
    func testParseTxHashes_HederaExecuteTransaction() {
        // Should work the same way for executeTransaction
        let expectedTransactionId = "0.0.98765432@1689281510.675369303"
        let resultModel = HederaMockFactory.createTransactionResult(transactionId: expectedTransactionId)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Test hash extraction
        let txHashes = hederaCollector.parseTxHashes(
            rpcMethod: "hedera_executeTransaction",
            rpcResult: rpcResult
        )
        
        XCTAssertEqual(txHashes, [expectedTransactionId])
    }
} 
