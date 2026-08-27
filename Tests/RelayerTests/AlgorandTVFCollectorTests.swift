import XCTest
@testable import WalletConnectRelay

final class AlgorandTVFCollectorTests: XCTestCase {
    
    private let algorandCollector = AlgorandTVFCollector()
    
    // Helper for creating RPCResult objects
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(algorandCollector.supportsMethod("algo_signTxn"))
        XCTAssertFalse(algorandCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(algorandCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_AlgoSignTxn() {
        // Test with real working data instead of mock data
        let signedTxnsBase64 = [
            "gqNzaWfEQNGPgbxS9pTu0sTikT3cJVO48WFltc8MM8meFR+aAnGwOo3FO+0nFkAludT0jNqHRM6E65gW6k/m92sHVCxVnQWjdHhuiaNhbXTOAAehIKNmZWXNA+iiZnbOAv0CO6NnZW6sbWFpbm5ldC12MS4womdoxCDAYcTY/B293tLXYEvkVo4/bQQZh6w3veS2ILWrOSSK36Jsds4C/QYjo3JjdsQgeqRNTBEXudHx2kO9Btq289aRzj5DlNUw0jwX9KEnaZqjc25kxCDH1s5tvgARbjtHceUG07Sj5IDfqzn7Zwx0P+XuvCYMz6R0eXBlo3BheQ=="
        ]
        
        // Production shape: RPCResult.response holds the already-unwrapped result value (the raw array)
        let rpcResult = RPCResult.response(AnyCodable(any: signedTxnsBase64))
        
        // Test hash extraction
        let txHashes = algorandCollector.parseTxHashes(
            rpcMethod: "algo_signTxn",
            rpcResult: rpcResult
        )
        
        // Verify we got transaction IDs
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.count, 1)
        XCTAssertEqual(txHashes?.first, "OM5JS3AE4HVAT5ZMCIMY32HPD6KJAQVPFS2LL2ZW2R5JKUKZFVNA")
    }
    
    func testCollectTxHashes_AlgoSignTxn_RealData() {
        // Arrange
        let rpcMethod = "algo_signTxn"
        // The response is an array of base64 encoded signed transactions
        let signedTxnsBase64 = [
            "gqNzaWfEQNGPgbxS9pTu0sTikT3cJVO48WFltc8MM8meFR+aAnGwOo3FO+0nFkAludT0jNqHRM6E65gW6k/m92sHVCxVnQWjdHhuiaNhbXTOAAehIKNmZWXNA+iiZnbOAv0CO6NnZW6sbWFpbm5ldC12MS4womdoxCDAYcTY/B293tLXYEvkVo4/bQQZh6w3veS2ILWrOSSK36Jsds4C/QYjo3JjdsQgeqRNTBEXudHx2kO9Btq289aRzj5DlNUw0jwX9KEnaZqjc25kxCDH1s5tvgARbjtHceUG07Sj5IDfqzn7Zwx0P+XuvCYMz6R0eXBlo3BheQ=="
        ]
        // Production shape: RPCResult.response holds the already-unwrapped result value (the raw array)
        let rpcResult = makeResponse(signedTxnsBase64)

        // Act
        let result = algorandCollector.parseTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult)

        // Assert
        XCTAssertNotNil(result)
        // https://explorer.perawallet.app/tx/OM5JS3AE4HVAT5ZMCIMY32HPD6KJAQVPFS2LL2ZW2R5JKUKZFVNA/
        let expectedTxId = "OM5JS3AE4HVAT5ZMCIMY32HPD6KJAQVPFS2LL2ZW2R5JKUKZFVNA"
        XCTAssertEqual(expectedTxId, result?.first)
    }
} 
