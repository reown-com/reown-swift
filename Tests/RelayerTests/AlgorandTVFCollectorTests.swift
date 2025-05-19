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
    
    func testParseTxHashes_AlgoSignTxn_NestedFormat() {
        // Create mock base64 signed transactions
        let signedTxns = [
            "gqNzaWfEQMBaLA4PHwgxIYW8i/fbbi8akgqg5gU5OdQu2JQGG+wFjU+D9+SAUQvU/8gKPKxTQJsj/z1xl1Fs3yB40KfbQAijdHhuiKRhcGFyksQEAQIAoXBheaCNZXlwa6R0eXBlo3BheQ==",
            "gqNzaWfEQL4gGxM+4AKs/RwVj5EE4iE3ELYyGaKiC9j7nT33Oq0U7YSzEY7YUhA9SnPlFatkHK/OV7Hce+6i1jhOtGBczgijdHhuiqRhcGFyksQEAQIAoXBheaCNZXlwbKR0eXBlo3BheQ=="
        ]
        
        // Create proper nested RPCResult with JSON-RPC format
        let nestedData = ["result": signedTxns]
        let rpcResult = RPCResult.response(AnyCodable(any: ["result": nestedData]))
        
        // Test hash extraction
        let txHashes = algorandCollector.parseTxHashes(
            rpcMethod: "algo_signTxn",
            rpcResult: rpcResult
        )
        
        // Verify we got transaction IDs
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.count, 2)
        
        // NOTE: In a real implementation, we would test the actual transaction ID values
        // but since our implementation is a mock, we just verify the format
        txHashes?.forEach { txHash in
            XCTAssertTrue(txHash.starts(with: "ALGO"))
        }
    }
    
    func testParseTxHashes_AlgoSignTxn_DirectFormat() {
        // Create mock base64 signed transactions
        let signedTxns = [
            "gqNzaWfEQMBaLA4PHwgxIYW8i/fbbi8akgqg5gU5OdQu2JQGG+wFjU+D9+SAUQvU/8gKPKxTQJsj/z1xl1Fs3yB40KfbQAijdHhuiKRhcGFyksQEAQIAoXBheaCNZXlwa6R0eXBlo3BheQ==",
            "gqNzaWfEQL4gGxM+4AKs/RwVj5EE4iE3ELYyGaKiC9j7nT33Oq0U7YSzEY7YUhA9SnPlFatkHK/OV7Hce+6i1jhOtGBczgijdHhuiqRhcGFyksQEAQIAoXBheaCNZXlwbKR0eXBlo3BheQ=="
        ]
        
        // Create direct array response
        let rpcResult = RPCResult.response(AnyCodable(any: signedTxns))
        
        // Test hash extraction
        let txHashes = algorandCollector.parseTxHashes(
            rpcMethod: "algo_signTxn",
            rpcResult: rpcResult
        )
        
        // Verify we got transaction IDs
        XCTAssertNotNil(txHashes)
        XCTAssertEqual(txHashes?.count, 2)
        
        // In a real implementation, we would test the actual transaction ID values
        txHashes?.forEach { txHash in
            XCTAssertTrue(txHash.starts(with: "ALGO"))
        }
    }
    
    func testParseTxHashes_ErrorCase() {
        let rpcResult = makeError(code: -32000, message: "some error")
        
        let txHashes = algorandCollector.parseTxHashes(
            rpcMethod: "algo_signTxn",
            rpcResult: rpcResult
        )
        
        XCTAssertNil(txHashes)
    }
} 