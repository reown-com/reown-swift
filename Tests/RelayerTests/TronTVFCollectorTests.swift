import XCTest
@testable import WalletConnectRelay

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
    
    func testExtractContractAddresses_AlwaysReturnsNil() {
        // Tron implementation currently doesn't extract contract addresses
        let rpcParams = AnyCodable([String]())
        let contractAddresses = tronCollector.extractContractAddresses(
            rpcMethod: "tron_signTransaction",
            rpcParams: rpcParams
        )
        XCTAssertNil(contractAddresses)
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_TronSignTransaction_DirectFormat() {
        // Direct response format
        let responseData: [String: Any] = [
            "txID": "66e79c6993f29b02725da54ab146ffb0453ee6a43b4083568ad9585da305374a",
            "signature": ["7e760cef94bc82a7533bc1e8d4ab88508c6e13224cd50cc8da62d3f4d4e19b99514f..."]
        ]
        let rpcResult = makeResponse(responseData)
        let txHashes = tronCollector.parseTxHashes(
            rpcMethod: "tron_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertEqual(txHashes, ["66e79c6993f29b02725da54ab146ffb0453ee6a43b4083568ad9585da305374a"])
    }
    
    func testParseTxHashes_TronSignTransaction_NestedResultFormat() {
        // Nested result format
        let responseData: [String: Any] = [
            "result": [
                "txID": "66e79c6993f29b02725da54ab146ffb0453ee6a43b4083568ad9585da305374a",
                "signature": ["7e760cef94bc82a7533bc1e8d4ab88508c6e13224cd50cc8da62d3f4d4e19b99514f..."]
            ]
        ]
        let rpcResult = makeResponse(responseData)
        let txHashes = tronCollector.parseTxHashes(
            rpcMethod: "tron_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertEqual(txHashes, ["66e79c6993f29b02725da54ab146ffb0453ee6a43b4083568ad9585da305374a"])
    }
    
    func testParseTxHashes_TronSignTransaction_MissingTxID() {
        // Missing txID field
        let responseData: [String: Any] = [
            "signature": ["7e760cef94bc82a7533bc1e8d4ab88508c6e13224cd50cc8da62d3f4d4e19b99514f..."]
        ]
        let rpcResult = makeResponse(responseData)
        let txHashes = tronCollector.parseTxHashes(
            rpcMethod: "tron_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
    
    func testParseTxHashes_TronSignTransaction_InvalidNestedFormat() {
        // Result field exists but is not a TronSignTransactionResult
        let responseData: [String: Any] = [
            "result": "invalid format"
        ]
        let rpcResult = makeResponse(responseData)
        let txHashes = tronCollector.parseTxHashes(
            rpcMethod: "tron_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
    
    func testParseTxHashes_UnsupportedMethod() {
        // Unsupported method should return nil
        let responseData: [String: Any] = [
            "txID": "66e79c6993f29b02725da54ab146ffb0453ee6a43b4083568ad9585da305374a"
        ]
        let rpcResult = makeResponse(responseData)
        let txHashes = tronCollector.parseTxHashes(
            rpcMethod: "unsupported_method",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
    
    func testParseTxHashes_ErrorCase() {
        let rpcResult = makeError(code: -32000, message: "some error")
        let txHashes = tronCollector.parseTxHashes(
            rpcMethod: "tron_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
    
    func testParseTxHashes_MalformedResponse() {
        let rpcResult = makeResponse("malformedData")
        let txHashes = tronCollector.parseTxHashes(
            rpcMethod: "tron_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
} 