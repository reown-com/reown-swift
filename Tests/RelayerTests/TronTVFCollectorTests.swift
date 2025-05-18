import XCTest
@testable import WalletConnectRelay

// MARK: - Single mock factory for all Tron test objects

public class TronMockFactory {
    static func createTransaction(
        contractAddress: String? = "41e9512d8d5b5412d2b9f3a4d5a87ca15c5c51f33",
        ownerAddress: String = "411cb0b7348eded93b8d0816bbeb819fc1d7a51f31",
        data: String = "7ff36ab50000000000000000000000000000000000000000000000000000421180000000",
        contractType: String = "TriggerSmartContract"
    ) -> TronTransaction {
        // Create value params, handling nil contractAddress
        var valueParams: [String: Any] = [
            "owner_address": ownerAddress,
            "data": data
        ]
        
        if let contractAddress = contractAddress {
            valueParams["contract_address"] = contractAddress
        }
        
        let parameterParams: [String: Any] = [
            "value": valueParams
        ]
        
        let contractParams: [String: Any] = [
            "parameter": parameterParams,
            "type": contractType
        ]
        
        let rawDataParams: [String: Any] = [
            "contract": [contractParams]
        ]
        
        let params: [String: Any] = [
            "raw_data": rawDataParams
        ]
        
        // Convert directly to JSON data
        let jsonData = try! JSONSerialization.data(withJSONObject: params)
        
        // Decode from JSON data
        return try! JSONDecoder().decode(TronTransaction.self, from: jsonData)
    }
    
    static func createTransactionResult(
        txID: String = "66e79c6993f29b02725da54ab146ffb0453ee6a43b4083568ad9585da305374a",
        signature: [String] = ["7e760cef94bc82a7533bc1e8d4ab88508c6e13224cd50cc8da62d3f4d4e19b99514f..."],
        contractAddress: String? = nil
    ) -> TronSignTransactionResult {
        // Create direct dictionary for JSON structure
        var params: [String: Any] = [
            "txID": txID,
            "signature": signature
        ]
        
        if let contractAddress = contractAddress {
            let valueParams: [String: Any] = [
                "contract_address": contractAddress,
                "owner_address": "411cb0b7348eded93b8d0816bbeb819fc1d7a51f31"
            ]
            
            let parameterParams: [String: Any] = [
                "value": valueParams
            ]
            
            let contractParams: [String: Any] = [
                "parameter": parameterParams,
                "type": "TriggerSmartContract"
            ]
            
            let rawDataParams: [String: Any] = [
                "contract": [contractParams]
            ]
            
            params["raw_data"] = rawDataParams
        }
        
        // Convert directly to JSON data
        let jsonData = try! JSONSerialization.data(withJSONObject: params)
        
        // Decode from JSON data
        return try! JSONDecoder().decode(TronSignTransactionResult.self, from: jsonData)
    }
}

final class TronTVFCollectorTests: XCTestCase {
    
    private let tronCollector = TronTVFCollector()
    
    // Helper: define sample .response(AnyCodable)
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(tronCollector.supportsMethod("tron_signTransaction"))
        XCTAssertFalse(tronCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(tronCollector.supportsMethod("solana_signTransaction"))
        XCTAssertFalse(tronCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Contract Address Extraction Tests
    
    func testExtractContractAddresses_FromDirectFormat() {
        // Test extraction using the TronTransaction model
        let txModel = TronMockFactory.createTransaction()
        let rpcParams = AnyCodable(txModel)
        
        let contractAddresses = tronCollector.extractContractAddresses(
            rpcMethod: "tron_signTransaction",
            rpcParams: rpcParams
        )
        
        XCTAssertEqual(contractAddresses, ["41e9512d8d5b5412d2b9f3a4d5a87ca15c5c51f33"])
    }
    
    func testExtractContractAddresses_NoContractAddress() {
        // Test with missing contract_address
        let txModel = TronMockFactory.createTransaction(contractAddress: nil)
        let rpcParams = AnyCodable(txModel)
        
        let contractAddresses = tronCollector.extractContractAddresses(
            rpcMethod: "tron_signTransaction",
            rpcParams: rpcParams
        )
        
        XCTAssertNil(contractAddresses)
    }

    func testExtractContractAddresses_MalformedParameters() {
        // Test with malformed parameters
        let rpcParams = AnyCodable("malformed_data")
        
        let contractAddresses = tronCollector.extractContractAddresses(
            rpcMethod: "tron_signTransaction",
            rpcParams: rpcParams
        )
        
        XCTAssertNil(contractAddresses)
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_TronSignTransaction() {
        // Create the transaction result with expected txID
        let expectedTxID = "66e79c6993f29b02725da54ab146ffb0453ee6a43b4083568ad9585da305374a"
        let resultModel = TronMockFactory.createTransactionResult(txID: expectedTxID)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Test hash extraction
        let txHashes = tronCollector.parseTxHashes(
            rpcMethod: "tron_signTransaction",
            rpcResult: rpcResult
        )
        
        XCTAssertEqual(txHashes, [expectedTxID])
    }
} 
