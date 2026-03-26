import XCTest
@testable import WalletConnectRelay

final class TonTVFCollectorTests: XCTestCase {

    private let tonCollector = TonTVFCollector()

    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }

    func testSupportsMethod() {
        XCTAssertTrue(tonCollector.supportsMethod("ton_sendMessage"))
        XCTAssertFalse(tonCollector.supportsMethod("eth_sendTransaction"))
    }

    func testParseTxHashes_TonSendMessage_DirectObject() {
        let expectedBoc = "boc_direct_base64"
        let rpcResult = makeResponse(["boc": expectedBoc])

        let hashes = tonCollector.parseTxHashes(
            rpcMethod: "ton_sendMessage",
            rpcResult: rpcResult
        )

        XCTAssertEqual(hashes, [expectedBoc])
    }
}

final class TonTVFCollectorIntegrationTests: XCTestCase {
    private var tvf: TVFCollector!
    private let chain = Blockchain("ton:mainnet")!

    private func makeResponse(_ value: Any) -> RPCResult {
        return .response(AnyCodable(any: value))
    }

    override func setUp() {
        super.setUp()
        tvf = TVFCollector()
    }

    func testTVFCollector_TonSendMessage_PutsBocIntoTxHashes() {
        let expectedBoc = "te6ccgEBAQEABgAABX...mock_boc...=="
        let rpcResult = makeResponse(["boc": expectedBoc])

        let data = tvf.collect(
            rpcMethod: "ton_sendMessage",
            rpcParams: AnyCodable([String]()),
            chainID: chain,
            rpcResult: rpcResult,
            tag: 1109 // sessionResponse
        )

        XCTAssertNotNil(data)
        XCTAssertEqual(data?.txHashes, [expectedBoc])
    }
}


