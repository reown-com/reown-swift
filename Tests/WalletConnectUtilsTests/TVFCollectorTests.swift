import XCTest
@testable import WalletConnectUtils

final class TVFCollectorTests: XCTestCase {

    private let tvf = TVFCollector()
    private let chain = Blockchain("eip155:1")!

    // Helper: define sample .response(AnyCodable)
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }

    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }

    // MARK: - Session Request (tag = 1108)

    func testSessionRequest_UnknownMethod_ReturnsNil() {
        let data = tvf.collect(
            rpcMethod: "not_supported",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: nil,
            tag: 1108
        )
        XCTAssertNil(data)
    }

    func testSessionRequest_EthSendTransaction_NormalTransaction_NoContractData() {
        // Supply a normal transaction with empty call data.
        // In this case the transaction is not a contract call so contractAddresses should be nil.
        let rpcParams = AnyCodable([
            [
                "from": "0x9876543210fedcba",
                "to": "0x1234567890abcdef",
                "data": ""  // empty data indicates no contract call
            ]
        ])
        let data = tvf.collect(
            rpcMethod: "eth_sendTransaction",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: nil,
            tag: 1108
        )
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.rpcMethods, ["eth_sendTransaction"])
        XCTAssertEqual(data?.chainId?.absoluteString, "eip155:1")
        XCTAssertNil(data?.contractAddresses)
        XCTAssertNil(data?.txHashes)
    }

    func testSessionRequest_EthSendTransaction_Malformed() {
        // If decoding fails → no contractAddresses
        let rpcParams = AnyCodable("malformed_data")
        let data = tvf.collect(
            rpcMethod: "eth_sendTransaction",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: nil,
            tag: 1108
        )
        XCTAssertNotNil(data)
        XCTAssertNil(data?.contractAddresses)
        XCTAssertNil(data?.txHashes)
    }

    func testSessionRequest_EthSendTransaction_WithValidContractData_ParsesContractAddress() {
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
        let data = tvf.collect(
            rpcMethod: "eth_sendTransaction",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: nil,
            tag: 1108
        )
        XCTAssertNotNil(data)
        // Expecting the valid contract call data to be detected so that the "to" address is returned.
        XCTAssertEqual(data?.contractAddresses, ["0x1234567890abcdef"])
    }

    // MARK: - Session Response (tag = 1109)

    func testSessionResponse_EthSendTransaction_ReturnsTxHash() {
        // EVM → parse single string from .response(AnyCodable)
        let rpcParams = AnyCodable([String]())
        let rpcResult = makeResponse("0x123abc")
        let data = tvf.collect(
            rpcMethod: "eth_sendTransaction",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, ["0x123abc"])
    }

    func testSessionResponse_EthSendTransaction_ErrorCase() {
        // If .error, then no txHashes
        let rpcParams = AnyCodable([String]())
        let rpcResult = makeError(code: -32000, message: "some error")
        let data = tvf.collect(
            rpcMethod: "eth_sendTransaction",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        XCTAssertNotNil(data)
        XCTAssertNil(data?.txHashes)
    }

    func testSessionResponse_SolanaSignTransaction_ReturnsSignature() {
        // "solana_signTransaction" → parse "signature" from .response(AnyCodable)
        let rpcParams = AnyCodable([String]())
        let responseData = ["signature": "0xsolanaSignature"]
        let rpcResult = makeResponse(responseData)
        let data = tvf.collect(
            rpcMethod: "solana_signTransaction",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, ["0xsolanaSignature"])
    }

    func testSessionResponse_SolanaSignTransaction_Malformed() {
        // If decoding fails → txHashes is nil
        let rpcParams = AnyCodable([String]())
        let rpcResult = makeResponse("malformedData")
        let data = tvf.collect(
            rpcMethod: "solana_signTransaction",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        XCTAssertNotNil(data)
        XCTAssertNil(data?.txHashes)
    }

    func testSessionResponse_SolanaSignAllTransactions_ReturnsTransactions() {
        let rpcParams = AnyCodable([String]())
        let responseData = ["transactions": ["tx1", "tx2"]]
        let rpcResult = makeResponse(responseData)
        let data = tvf.collect(
            rpcMethod: "solana_signAllTransactions",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, ["tx1", "tx2"])
    }

    func testSessionResponse_UnsupportedMethod_ReturnsNil() {
        let rpcParams = AnyCodable([String]())
        let rpcResult = makeResponse("whatever")
        let data = tvf.collect(
            rpcMethod: "someUnsupportedMethod",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        XCTAssertNil(data)
    }
}
