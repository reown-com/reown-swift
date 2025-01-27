import XCTest

@testable import WalletConnectUtils

final class TVFCollectorTests: XCTestCase {

    private let tvf = TVFCollector()

    // MARK: - collect tests

    func testCollectShouldReturnNilWhenRpcMethodIsNotInTheAllowedList() {
        // Arrange
        let rpcMethod = "unsupported_method"
        let rpcParams = "{}"
        let chainId = "1"

        // Act
        let result = tvf.collect(rpcMethod: rpcMethod, rpcParams: rpcParams, chainId: chainId)

        // Assert
        XCTAssertNil(result)
    }

    func testCollectShouldParseEthSendTransactionCorrectly() {
        // Arrange
        let rpcMethod = "eth_sendTransaction"
        let rpcParams = "[{\"to\": \"0x1234567890abcdef\", \"from\": \"0x1234567890abcdef\"}]"
        let chainId = "1"

        // Act
        let result = tvf.collect(rpcMethod: rpcMethod, rpcParams: rpcParams, chainId: chainId)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods, ["eth_sendTransaction"])
        XCTAssertEqual(result?.contractAddresses, ["0x1234567890abcdef"])
        XCTAssertEqual(result?.chainId, "1")
    }

    func testCollectShouldReturnDefaultValueWhenParsingEthSendTransactionFails() {
        // Arrange
        let rpcMethod = "eth_sendTransaction"
        let rpcParams = "{malformed_json}"
        let chainId = "1"

        // Act
        let result = tvf.collect(rpcMethod: rpcMethod, rpcParams: rpcParams, chainId: chainId)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.methods, ["eth_sendTransaction"])
        XCTAssertNil(result?.contractAddresses)
        XCTAssertEqual(result?.chainId, "1")
    }

    // MARK: - collectTxHashes tests

    func testCollectTxHashesShouldReturnRpcResultForEvmAndWalletMethods() {
        // Arrange
        let rpcMethod = "eth_sendTransaction"
        let rpcResult = "0x123abc"

        // Act
        let result = tvf.collectTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result, ["0x123abc"])
    }

    func testCollectTxHashesShouldParseSolanaSignTransactionAndReturnSignature() {
        // Arrange
        let rpcMethod = "solana_signTransaction"
        let rpcResult = "{\"signature\": \"0xsignature123\"}"

        // Act
        let result = tvf.collectTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result, ["0xsignature123"])
    }

    func testCollectTxHashesShouldReturnNilWhenParsingSolanaSignTransactionFails() {
        // Arrange
        let rpcMethod = "solana_signTransaction"
        let rpcResult = "{malformed_json}"

        // Act
        let result = tvf.collectTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult)

        // Assert
        XCTAssertNil(result)
    }

    func testCollectTxHashesShouldParseSolanaSignAndSendTransactionAndReturnSignature() {
        // Arrange
        let rpcMethod = "solana_signAndSendTransaction"
        let rpcResult = "{\"signature\": \"0xsendAndSignSignature\"}"

        // Act
        let result = tvf.collectTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result, ["0xsendAndSignSignature"])
    }

    func testCollectTxHashesShouldParseSolanaSignAllTransactionsAndReturnAllTransactions() {
        // Arrange
        let rpcMethod = "solana_signAllTransactions"
        let rpcResult = "{\"transactions\": [\"tx1\", \"tx2\"]}"

        // Act
        let result = tvf.collectTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result, ["tx1", "tx2"])
    }

    func testCollectTxHashesShouldReturnNilForUnsupportedMethods() {
        // Arrange
        let rpcMethod = "unsupported_method"
        let rpcResult = "some_result"

        // Act
        let result = tvf.collectTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult)

        // Assert
        XCTAssertNil(result)
    }
}
