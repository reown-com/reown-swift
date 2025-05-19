import XCTest
@testable import WalletConnectRelay

final class TVFCollectorTests: XCTestCase {
    
    private var tvf: TVFCollector!
    private let chain = Blockchain("eip155:1")!
    
    // Helper: define sample .response(AnyCodable)
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    override func setUp() {
        super.setUp()
        tvf = TVFCollector()
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
            "AWHu1QYry2PqYQAxDBXUtxBjRorQecJEVzje2rVY2rKJ6usAMAC/f0GGSqxpWlaS93wIfg3FqPPMzAKDdxgTwQwBAAIDb3ObYkq6BFd46JrMFy1h0Q+dGmyRGtpelqTKkIg82isAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMGRm/lIRcy/+ytunLDm+e8jOW7xfcSayxDmzpAAAAA58ONgFXrro2UqR0pvpUDFIqAYRJMYUnemdWXhfWu8VcDAgAFAlgCAAABAgAADAIAAACghgEAAAAAAAIACQMjTgAAAAAAAA=="
        ]
        
        let responseData = ["transactions": transactions]
        let rpcResult = makeResponse(responseData)
        
        // Expected signatures
        let expectedSignatures = [
            "3oi6k2bd1fQdUenuMSeP3Zr18a3iRMuFcbgTnehBrQZP6nftmsVqMi1np4ENJr5HmuSgSsejfUYYpqTCXhnadSjw",
            "2xZgx9T8kpRRmbkWhBzyfwH6FFc5ZTXAsZUAnU6MyemAqR2fqic7LAbi1ZjALC51NYkyC7hYKFB1rxRTXMQKmTmD"
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

    func testSessionRequest_TronSignTransaction_ExtractsContractAddresses() {
        // Create Tron transaction request with contract address using the model format
        let txModel = TronMockFactory.createTransaction()
        let rpcParams = AnyCodable(txModel)
        
        // Act
        let data = tvf.collect(
            rpcMethod: "tron_signTransaction",
            rpcParams: rpcParams,
            chainID: chain,
            rpcResult: nil,
            tag: 1108
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.rpcMethods, ["tron_signTransaction"])
        XCTAssertEqual(data?.chainId?.absoluteString, "eip155:1")
        XCTAssertEqual(data?.contractAddresses, ["41e9512d8d5b5412d2b9f3a4d5a87ca15c5c51f33"])
        XCTAssertNil(data?.txHashes)
    }

    func testSessionResponse_TronSignTransaction_ExtractsTxIDCorrectly() {
        // Create the transaction result with expected txID
        let expectedTxID = "66e79c6993f29b02725da54ab146ffb0453ee6a43b4083568ad9585da305374a"
        let resultModel = TronMockFactory.createTransactionResult(txID: expectedTxID)
        
        // Create proper nested RPCResult with result field
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Act
        let data = tvf.collect(
            rpcMethod: "tron_signTransaction",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, [expectedTxID])
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

    func testInvalidTag_ReturnsNil() {
        // Execute with an invalid tag
        let data = tvf.collect(
            rpcMethod: "eth_sendTransaction",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: nil,
            tag: 9999 // Invalid tag
        )
        
        // Verify
        XCTAssertNil(data)
    }

    func testSessionResponse_XRPLSignTransaction_ExtractsHashCorrectly() {
        // Create the transaction result with expected hash
        let expectedHash = "73734B611DDA23D3F5F62E20A173B78AB8406AC5015094DA53F53D39B9EDB06C"
        let resultModel = XRPLMockFactory.createTransactionResult(hash: expectedHash)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Act
        let data = tvf.collect(
            rpcMethod: "xrpl_signTransaction",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, [expectedHash])
    }

    func testSessionResponse_XRPLSignTransactionFor_ExtractsHashCorrectly() {
        // Create the transaction result with expected hash
        let expectedHash = "BA2AF0C652F46C97B85C1D17080EEC7422C092B0BD906DCA344B42EF30FA8285"
        let resultModel = XRPLMockFactory.createTransactionResult(hash: expectedHash)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Act
        let data = tvf.collect(
            rpcMethod: "xrpl_signTransactionFor",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, [expectedHash])
    }

    func testSessionResponse_HederaSignAndExecuteTransaction_ExtractsTransactionIdCorrectly() {
        // Create the transaction result with expected transaction ID
        let expectedTransactionId = "0.0.12345678@1689281510.675369303"
        let resultModel = HederaMockFactory.createTransactionResult(transactionId: expectedTransactionId)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Act
        let data = tvf.collect(
            rpcMethod: "hedera_signAndExecuteTransaction",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, [expectedTransactionId])
    }

    func testSessionResponse_HederaExecuteTransaction_ExtractsTransactionIdCorrectly() {
        // Create the transaction result with expected transaction ID
        let expectedTransactionId = "0.0.98765432@1689281510.675369303"
        let resultModel = HederaMockFactory.createTransactionResult(transactionId: expectedTransactionId)
        
        // Create proper nested RPCResult
        let jsonData = try! JSONEncoder().encode(resultModel)
        let jsonDict = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let nestedData = ["result": jsonDict]
        let rpcResult = RPCResult.response(AnyCodable(any: nestedData))
        
        // Act
        let data = tvf.collect(
            rpcMethod: "hedera_executeTransaction",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, [expectedTransactionId])
    }

    func testSessionResponse_AlgoSignTxn_ExtractsTransactionIdsCorrectly() {
        // Create mock base64 signed transactions
        let signedTxns = [
            "gqNzaWfEQMBaLA4PHwgxIYW8i/fbbi8akgqg5gU5OdQu2JQGG+wFjU+D9+SAUQvU/8gKPKxTQJsj/z1xl1Fs3yB40KfbQAijdHhuiKRhcGFyksQEAQIAoXBheaCNZXlwa6R0eXBlo3BheQ==",
            "gqNzaWfEQL4gGxM+4AKs/RwVj5EE4iE3ELYyGaKiC9j7nT33Oq0U7YSzEY7YUhA9SnPlFatkHK/OV7Hce+6i1jhOtGBczgijdHhuiqRhcGFyksQEAQIAoXBheaCNZXlwbKR0eXBlo3BheQ=="
        ]
        
        // Create proper JSON-RPC format response
        let rpcResult = RPCResult.response(AnyCodable(any: ["result": signedTxns]))
        
        // Act
        let data = tvf.collect(
            rpcMethod: "algo_signTxn",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertNotNil(data?.txHashes)
        XCTAssertEqual(data?.txHashes?.count, 2)
    }

    func testSessionResponse_SuiSignAndExecuteTransaction_ExtractsDigestCorrectly() {
        // Create transaction result with expected digest
        let expectedDigest = "8cZk5Zj1sMZes9jBxrKF3Nv8uZJor3V5XTFmxp3GTxhp"
        let resultModel = SuiMockFactory.createSignAndExecuteTransactionResult(digest: expectedDigest)
        
        // Create proper JSON-RPC format response (Tron-style)
        // 1. Encode the resultModel to JSON Data
        let resultModelData = try! JSONEncoder().encode(resultModel)
        // 2. Convert JSON Data to a [String: Any] dictionary
        let resultModelJsonDict = try! JSONSerialization.jsonObject(with: resultModelData) as! [String: Any]
        // 3. Create the payload dictionary for AnyCodable(any:)
        let rpcPayloadForAnyCodable: [String: Any] = ["result": resultModelJsonDict]
        // 4. Wrap this payload using AnyCodable(any:)
        let rpcResult = RPCResult.response(AnyCodable(any: rpcPayloadForAnyCodable))
        
        // Act
        let data = tvf.collect(
            rpcMethod: "sui_signAndExecuteTransaction",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109
        )
        
        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, [expectedDigest])
    }
}
