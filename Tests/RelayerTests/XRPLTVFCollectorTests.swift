import XCTest
@testable import WalletConnectRelay

// MARK: - Mock factory for XRPL test objects

public class XRPLMockFactory {
    static func createTransactionResult(
        hash: String = "73734B611DDA23D3F5F62E20A173B78AB8406AC5015094DA53F53D39B9EDB06C"
    ) -> XRPLSignTransactionResult {
        // Create a mock result with a hash value
        let txJson = XRPLSignTransactionResult.TxJson(hash: hash)
        return XRPLSignTransactionResult(tx_json: txJson)
    }
}

final class XRPLTVFCollectorTests: XCTestCase {
    
    private let xrplCollector = XRPLTVFCollector()
    
    // Helper for creating RPCResult objects
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(xrplCollector.supportsMethod("xrpl_signTransaction"))
        XCTAssertTrue(xrplCollector.supportsMethod("xrpl_signTransactionFor"))
        XCTAssertFalse(xrplCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(xrplCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Contract Address Extraction Tests
    
    func testExtractContractAddresses_ReturnsNil() {
        // XRPL doesn't use contract addresses in TVF
        let rpcParams = AnyCodable("any_params")
        
        let contractAddresses = xrplCollector.extractContractAddresses(
            rpcMethod: "xrpl_signTransaction",
            rpcParams: rpcParams
        )
        
        XCTAssertNil(contractAddresses)
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_XRPLSignTransaction() {
        // Create transaction result with expected hash
        let expectedHash = "73734B611DDA23D3F5F62E20A173B78AB8406AC5015094DA53F53D39B9EDB06C"
        let resultModel = XRPLMockFactory.createTransactionResult(hash: expectedHash)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Test hash extraction
        let txHashes = xrplCollector.parseTxHashes(
            rpcMethod: "xrpl_signTransaction",
            rpcResult: rpcResult
        )
        
        XCTAssertEqual(txHashes, [expectedHash])
    }
    
    func testParseTxHashes_XRPLSignTransactionFor() {
        // Should work the same way for signTransactionFor
        let expectedHash = "BA2AF0C652F46C97B85C1D17080EEC7422C092B0BD906DCA344B42EF30FA8285"
        let resultModel = XRPLMockFactory.createTransactionResult(hash: expectedHash)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Test hash extraction
        let txHashes = xrplCollector.parseTxHashes(
            rpcMethod: "xrpl_signTransactionFor",
            rpcResult: rpcResult
        )
        
        XCTAssertEqual(txHashes, [expectedHash])
    }
} 
