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
        // Create mock base64 signed transactions
        let signedTxns = [
            "gqNzaWfEQMBaLA4PHwgxIYW8i/fbbi8akgqg5gU5OdQu2JQGG+wFjU+D9+SAUQvU/8gKPKxTQJsj/z1xl1Fs3yB40KfbQAijdHhuiKRhcGFyksQEAQIAoXBheaCNZXlwa6R0eXBlo3BheQ==",
            "gqNzaWfEQL4gGxM+4AKs/RwVj5EE4iE3ELYyGaKiC9j7nT33Oq0U7YSzEY7YUhA9SnPlFatkHK/OV7Hce+6i1jhOtGBczgijdHhuiqRhcGFyksQEAQIAoXBheaCNZXlwbKR0eXBlo3BheQ=="
        ]
        
        // Create proper nested RPCResult with JSON-RPC format
        let nestedData = ["result": signedTxns]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Test hash extraction
        let txHashes = algorandCollector.parseTxHashes(
            rpcMethod: "algo_signTxn",
            rpcResult: rpcResult
        )
        
        // Verify we got transaction IDs
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.count, 2)
        
        // Verify format of the transaction IDs (actual values will depend on hash result)
        XCTAssertFalse(txHashes?.isEmpty ?? true)
    }

    func testParseTxHashes_KnownSignedTransaction_ReturnsExpectedTxId() {
        // This base64 signed transaction is taken from integration tests and
        // its txID was calculated using the Algorand SDK implementation.
        let signedTxn = "gqNzaWfEQMBaLA4PHwgxIYW8i/fbbi8akgqg5gU5OdQu2JQGG+wFjU+D9+SAUQvU/8gKPKxTQJsj/z1xl1Fs3yB40KfbQAijdHhuiKRhcGFyksQEAQIAoXBheaCNZXlwa6R0eXBlo3BheQ=="

        // Wrap transaction in JSON-RPC style response
        let nestedData = ["result": [signedTxn]]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))

        let txHashes = algorandCollector.parseTxHashes(
            rpcMethod: "algo_signTxn",
            rpcResult: rpcResult
        )

        let expectedTxID = "RODKDC3A3TWN3D6QYA5SWN53SKKM4O24JU2X4LYDFURFM7IEP3TA"
        XCTAssertEqual(txHashes, [expectedTxID])
    }
}
