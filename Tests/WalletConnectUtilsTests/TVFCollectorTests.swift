import XCTest

@testable import WalletConnectUtils

final class TVFCollectorTests: XCTestCase {

    private let tvf = TVFCollector()
    private let validChain = Blockchain("eip155:1")!

    // MARK: - sessionRequest (1008) tests

    func testSessionRequest_UnknownMethod_ReturnsNil() {
        // Arrange
        let rpcMethod = "unsupported_method"
        let rpcParams = AnyCodable([String]()) // empty array or anything
        let rpcResult: String? = nil
        let tag = 1008  // sessionRequest

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNil(data, "Expected nil for unrecognized RPC method.")
    }

    func testSessionRequest_EthSendTransaction_ParsesContractAddress() {
        // Arrange
        let rpcMethod = "eth_sendTransaction"
        let rpcParams = AnyCodable([
            [
                "from": "0x9876543210fedcba",
                "to": "0x1234567890abcdef"
            ]
        ])
        let rpcResult: String? = nil
        let tag = 1008 // sessionRequest

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.rpcMethods, ["eth_sendTransaction"])
        XCTAssertEqual(data?.chainId?.absoluteString, "eip155:1")
        XCTAssertEqual(data?.contractAddresses, ["0x1234567890abcdef"])
        XCTAssertNil(data?.txHashes, "No txHashes for sessionRequest")
    }

    func testSessionRequest_EthSendTransaction_Malformed() {
        // This scenario simulates passing something that cannot decode to [EthSendTransaction].
        // E.g., a simple string or a dictionary missing fields, etc.
        // Arrange
        let rpcMethod = "eth_sendTransaction"
        let rpcParams = AnyCodable("malformed_data")
        let rpcResult: String? = nil
        let tag = 1008

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNotNil(data, "We do get back data, but contract addresses is nil.")
        XCTAssertEqual(data?.rpcMethods, ["eth_sendTransaction"])
        XCTAssertEqual(data?.chainId?.absoluteString, "eip155:1")
        XCTAssertNil(data?.contractAddresses, "Failed to decode => nil addresses")
        XCTAssertNil(data?.txHashes)
    }

    // MARK: - sessionResponse (1009) tests

    func testSessionResponse_EthSendTransaction_ReturnsTxHash() {
        // EVM => return rpcResult as single-element array if tag == 1009
        // Arrange
        let rpcMethod = "eth_sendTransaction"
        let rpcParams = AnyCodable([String]()) // empty array or anything
        let rpcResult = "0x123abc"
        let tag = 1009

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.rpcMethods, ["eth_sendTransaction"])
        XCTAssertEqual(data?.chainId?.absoluteString, "eip155:1")
        XCTAssertEqual(data?.txHashes, ["0x123abc"])
    }

    func testSessionResponse_SolanaSignTransaction_ReturnsSignature() {
        // Arrange
        let rpcMethod = "solana_signTransaction"
        let rpcParams = AnyCodable([String]()) // empty array or anything
        let rpcResult = """
        {
          "signature": "0xsignature123"
        }
        """
        let tag = 1009

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.rpcMethods, ["solana_signTransaction"])
        XCTAssertEqual(data?.txHashes, ["0xsignature123"])
    }

    func testSessionResponse_SolanaSignTransaction_MalformedJson() {
        // If we cannot parse the signature, txHashes should be nil
        // Arrange
        let rpcMethod = "solana_signTransaction"
        let rpcParams = AnyCodable([String]()) // empty array or anything
        let rpcResult = "{malformed"
        let tag = 1009

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.rpcMethods, ["solana_signTransaction"])
        XCTAssertNil(data?.txHashes, "Malformed => no signature parsed")
    }

    func testSessionResponse_SolanaSignAndSendTransaction_ReturnsSignature() {
        // Arrange
        let rpcMethod = "solana_signAndSendTransaction"
        let rpcParams = AnyCodable([String]()) // empty array or anything
        let rpcResult = """
        {
          "signature": "0xsendAndSignSignature"
        }
        """
        let tag = 1009

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.rpcMethods, ["solana_signAndSendTransaction"])
        XCTAssertEqual(data?.txHashes, ["0xsendAndSignSignature"])
    }

    func testSessionResponse_SolanaSignAllTransactions_ReturnsAllTransactions() {
        // Arrange
        let rpcMethod = "solana_signAllTransactions"
        let rpcParams = AnyCodable([String]())
        let rpcResult = """
        {
          "transactions": ["tx1", "tx2"]
        }
        """
        let tag = 1009

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.rpcMethods, ["solana_signAllTransactions"])
        XCTAssertEqual(data?.txHashes, ["tx1", "tx2"])
    }

    func testSessionResponse_UnsupportedMethod_ReturnsNil() {
        // Arrange
        let rpcMethod = "someUnsupportedMethod"
        let rpcParams = AnyCodable([String]())   
        let rpcResult = "anything"
        let tag = 1009

        // Act
        let data = tvf.collect(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams,
            chainID: validChain,
            rpcResult: rpcResult,
            tag: tag
        )

        // Assert
        XCTAssertNil(data)
    }
}
