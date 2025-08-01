import XCTest
@testable import WalletConnectRelay

final class EVMTVFCollectorTests: XCTestCase {
    
    private let evmCollector = EVMTVFCollector()
    
    // Helper: define sample .response(AnyCodable)
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(evmCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertTrue(evmCollector.supportsMethod("eth_sendRawTransaction"))
        XCTAssertTrue(evmCollector.supportsMethod("wallet_sendCalls"))
        XCTAssertFalse(evmCollector.supportsMethod("solana_signTransaction"))
        XCTAssertFalse(evmCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Contract Address Extraction Tests
    
    func testExtractContractAddresses_NormalTransaction_NoContractData() {
        // Supply a normal transaction with empty call data.
        // In this case the transaction is not a contract call so contractAddresses should be nil.
        let rpcParams = AnyCodable([
            [
                "from": "0x9876543210fedcba",
                "to": "0x1234567890abcdef",
                "data": ""  // empty data indicates no contract call
            ]
        ])
        let contractAddresses = evmCollector.extractContractAddresses(
            rpcMethod: "eth_sendTransaction",
            rpcParams: rpcParams
        )
        XCTAssertNil(contractAddresses)
    }
    
    func testExtractContractAddresses_MalformedData() {
        // If decoding fails → no contractAddresses
        let rpcParams = AnyCodable("malformed_data")
        let contractAddresses = evmCollector.extractContractAddresses(
            rpcMethod: "eth_sendTransaction",
            rpcParams: rpcParams
        )
        XCTAssertNil(contractAddresses)
    }
    
    func testExtractContractAddresses_WithValidContractData() {
        // Construct a valid contract call data string:
        // - 8 hex chars for method ID: "abcd1234"
        // - 64 hex chars for recipient: "0000000000000000000000001111111111111111111111111111111111111111"
        // - At least 1 hex char for amount (here we use 62 zeros then "f0")
        let validContractData = "0xabcd12340000000000000000000000111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000f0"
        let rpcParams = AnyCodable([
            [
                "from": "0x9876543210fedcba",
                "to": "0x1234567890abcdef",
                "data": validContractData
            ]
        ])
        let contractAddresses = evmCollector.extractContractAddresses(
            rpcMethod: "eth_sendTransaction",
            rpcParams: rpcParams
        )
        // Expecting the valid contract call data to be detected so that the "to" address is returned.
        XCTAssertEqual(contractAddresses, ["0x1234567890abcdef"])
    }
    
    func testExtractContractAddresses_NonEthSendTransaction() {
        let rpcParams = AnyCodable([String]())
        let contractAddresses = evmCollector.extractContractAddresses(
            rpcMethod: "eth_sendRawTransaction",
            rpcParams: rpcParams
        )
        XCTAssertNil(contractAddresses)
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_ValidResponse() {
        let rpcResult = makeResponse("0x123abc")
        let txHashes = evmCollector.parseTxHashes(
            rpcMethod: "eth_sendTransaction",
            rpcResult: rpcResult
        )
        XCTAssertEqual(txHashes, ["0x123abc"])
    }
    
    func testParseTxHashes_ErrorCase() {
        let rpcResult = makeError(code: -32000, message: "some error")
        let txHashes = evmCollector.parseTxHashes(
            rpcMethod: "eth_sendTransaction",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
    
    func testParseTxHashes_MalformedResponse() {
        let rpcResult = makeResponse(["wrongFormat": true])
        let txHashes = evmCollector.parseTxHashes(
            rpcMethod: "eth_sendTransaction",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
    
    // MARK: - Contract Data Validation Tests
    
    func testIsValidContractData_ValidData() {
        let validData = "0xabcd12340000000000000000000000111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000f0"
        XCTAssertTrue(EVMTVFCollector.isValidContractData(validData))
    }
    
    func testIsValidContractData_InvalidData() {
        // Too short
        XCTAssertFalse(EVMTVFCollector.isValidContractData("0x1234"))
        // Empty
        XCTAssertFalse(EVMTVFCollector.isValidContractData(""))
        // No method ID
        XCTAssertFalse(EVMTVFCollector.isValidContractData("0x0000000000000000000000000000000000000000000000000000000000000000"))
        // No recipient
        XCTAssertFalse(EVMTVFCollector.isValidContractData("0xabcd12340000000000000000000000000000000000000000000000000000000000000000"))
        // No amount
        XCTAssertFalse(EVMTVFCollector.isValidContractData("0xabcd12340000000000000000000000111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000"))
    }
} 