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

    func testSessionResponse_SolanaSignAllTransactions_ExtractsSignaturesCorrectly() {
        // Arrange
        let transactions = [
            "AYxQUCwuEoBMHp45bxp9yyegtoVUcyyc0idYrBan1PW/mWWA4MrXsbytuJt9FP1tXH5ZxYYyKc3YmBM+hcueqA4BAAIDb3ObYkq6BFd46JrMFy1h0Q+dGmyRGtpelqTKkIg82isAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMGRm/lIRcy/+ytunLDm+e8jOW7xfcSayxDmzpAAAAAanHwLXEo8xArFhOhqld18H+7VdHJSIY4f27y1qCK4AoDAgAFAlgCAAABAgAADAIAAACghgEAAAAAAAIACQMgTgAAAAAAAA==",
            "AWHu1QYry2PqYQAxDBXUtxBjRorQecJEVzje2rVY2rKJ6usAMAC/f0GGSqxpWlaS93wIfg3FqPPMzAKDdxgTwQwBAAIDb3ObYkq6BFd46JrMFy1h0Q+dGmyRGtpelqTKkIg82isAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMGRm/lIRcy/+ytunLDm+e8jOW7xfcSayxDmzpAAAAA58ONgFXrro2UqR0pvpUDFIqAYRJMYUnemdWXhfWu8VcDAgAFAlgCAAABAgAADAIAAACghgEAAAAAAAIACQMgTgAAAAAAAA==",
            "AeJw688VKMWEeOHsYhe03By/2rqJHTQeq6W4L1ZLdbT2l/Nim8ctL3erMyH9IWPsQP73uaarRmiVfanEJHx7uQ4BAAIDb3ObYkq6BFd46JrMFy1h0Q+dGmyRGtpelqTKkIg82isAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMGRm/lIRcy/+ytunLDm+e8jOW7xfcSayxDmzpAAAAAtIy17v5fs39LuoitzpBhVrg8ZIQF/3ih1N9dQ+X3shEDAgAFAlgCAAABAgAADAIAAACghgEAAAAAAAIACQMjTgAAAAAAAA=="
        ]
        
        let responseData = ["transactions": transactions]
        let rpcResult = makeResponse(responseData)
        
        // Expected signatures
        let expectedSignatures = [
            "3oi6k2bd1fQdUenuMSeP3Zr18a3iRMuFcbgTnehBrQZP6nftmsVqMi1np4ENJr5HmuSgSsejfUYYpqTCXhnadSjw",
            "2xZgx9T8kpRRmbkWhBzyfwH6FFc5ZTXAsZUAnU6MyemAqR2fqic7LAbi1ZjALC51NYkyC7hYKFB1rxRTXMQKmTmD",
            "5XanD5KnkqzH3RjyqHzPCSRrNXYW2ADH4bge4oMi9KnDBrkFvugagH3LytFZFmBhZEEcyxPsZqeyF4cgLpEXVFR7"
        ]
        
        // Act
        let data = tvf.collect(
            rpcMethod: "solana_signAllTransactions",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, expectedSignatures)
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
