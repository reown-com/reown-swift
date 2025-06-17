import XCTest
@testable import WalletConnectRelay

final class SolanaTVFCollectorTests: XCTestCase {
    
    private let solanaCollector = SolanaTVFCollector()
    
    // Helper: define sample .response(AnyCodable)
    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }
    
    private func makeError(code: Int, message: String) -> RPCResult {
        return .error(JSONRPCError(code: code, message: message))
    }
    
    // MARK: - Method Support Tests
    
    func testSupportsMethod() {
        XCTAssertTrue(solanaCollector.supportsMethod("solana_signTransaction"))
        XCTAssertTrue(solanaCollector.supportsMethod("solana_signAndSendTransaction"))
        XCTAssertTrue(solanaCollector.supportsMethod("solana_signAllTransactions"))
        XCTAssertFalse(solanaCollector.supportsMethod("eth_sendTransaction"))
        XCTAssertFalse(solanaCollector.supportsMethod("unknown_method"))
    }
    
    // MARK: - Contract Address Extraction Tests
    
    func testExtractContractAddresses_AlwaysReturnsNil() {
        // Solana implementation currently doesn't extract contract addresses
        let rpcParams = AnyCodable([String]())
        let contractAddresses = solanaCollector.extractContractAddresses(
            rpcMethod: "solana_signTransaction",
            rpcParams: rpcParams
        )
        XCTAssertNil(contractAddresses)
    }
    
    // MARK: - Transaction Hash Parsing Tests
    
    func testParseTxHashes_SolanaSignTransaction() {
        let responseData = ["signature": "0xsolanaSignature"]
        let rpcResult = makeResponse(responseData)
        let txHashes = solanaCollector.parseTxHashes(
            rpcMethod: "solana_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertEqual(txHashes, ["0xsolanaSignature"])
    }
    
    func testParseTxHashes_SolanaSignAndSendTransaction() {
        let responseData = ["signature": "0xsolanaSignAndSendSignature"]
        let rpcResult = makeResponse(responseData)
        let txHashes = solanaCollector.parseTxHashes(
            rpcMethod: "solana_signAndSendTransaction",
            rpcResult: rpcResult
        )
        XCTAssertEqual(txHashes, ["0xsolanaSignAndSendSignature"])
    }
    
    func testParseTxHashes_SolanaSignAllTransactions() {
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
        let txHashes = solanaCollector.parseTxHashes(
            rpcMethod: "solana_signAllTransactions",
            rpcResult: rpcResult
        )
        
        // Assert
        XCTAssertEqual(txHashes, expectedSignatures)
    }
    
    func testParseTxHashes_ErrorCase() {
        let rpcResult = makeError(code: -32000, message: "some error")
        let txHashes = solanaCollector.parseTxHashes(
            rpcMethod: "solana_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
    
    func testParseTxHashes_MalformedResponse() {
        let rpcResult = makeResponse("malformedData")
        let txHashes = solanaCollector.parseTxHashes(
            rpcMethod: "solana_signTransaction",
            rpcResult: rpcResult
        )
        XCTAssertNil(txHashes)
    }
} 