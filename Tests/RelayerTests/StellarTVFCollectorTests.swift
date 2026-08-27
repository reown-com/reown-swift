import XCTest
@testable import WalletConnectRelay

final class StellarTVFCollectorTests: XCTestCase {

    private let stellarCollector = StellarTVFCollector()

    // Stellar test vectors are real transactions fetched from Horizon
    // (expected hash == the `hash` field of `GET /transactions/{hash}`).

    private static let pubnetV1XDR =
        "AAAAAgAAAACutgsH0wwp9iT1V1zWE8jbQAm7JNeTEx4zdvWD4Jtk8wAAAGQDymekAAAAHAAAAAEAAAAAAAAAAAAAAABqguWuAAAAAAAAAAEAAAAAAAAAAQAAAACutgsH0wwp9iT1V1zWE8jbQAm7JNeTEx4zdvWD4Jtk8wAAAAAAAAAAAJiWgAAAAAAAAAAB4Jtk8wAAAECrfMK7BzVXCay0QnEItO7dJ8Ix2wGaMnFfbWHW1tE6cezMinDXiDtlVBwoK2GjAbrE0h+eGDjDqWWaRS1XDrwE"
    private static let pubnetV1Hash = "628ef4f404cba337f757a640260984830728c92101af0a051fb59fc8c79521c6"

    private static let pubnetFeeBumpXDR =
        "AAAABQAAAAA0mMHF8QGzwsMRBhe9i8PSIqxjNjKyQMyXZODBAdhAUwAAAAAAA5+BAAAAAgAAAAA6Hd6p+AA5GTO2bJqKN/hbBfWcOh2Ow8cnTY3iIFFVPAADnrgDoCvmAAAZVgAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAABAAAAADod3qn4ADkZM7Zsmoo3+FsF9Zw6HY7DxydNjeIgUVU8AAAAGAAAAAAAAAAB1/5EvQrxHWArEJHy9KH03yEtRE0DIeoyrbPMHLurCgQAAAAEd29yawAAAAMAAAASAAAAAAAAAAA6Hd6p+AA5GTO2bJqKN/hbBfWcOh2Ow8cnTY3iIFFVPAAAAA0AAAAgAAAAjpSFVoEyx/Ev5d2V/desEr+GEqMyXKvrs5wXFqwAAAAFAAAAAAIrSjwAAAAAAAAAAQAAAAAAAAABAAAAB9ssFCkNSWTjgF8lJ90TKTm6X7P8ysVrML+rj9CRARYnAAAAAwAAAAYAAAAB1/5EvQrxHWArEJHy9KH03yEtRE0DIeoyrbPMHLurCgQAAAAQAAAAAQAAAAIAAAAPAAAABUJsb2NrAAAAAAAAAwACsj8AAAAAAAAABgAAAAHX/kS9CvEdYCsQkfL0ofTfIS1ETQMh6jKts8wcu6sKBAAAABAAAAABAAAAAwAAAA8AAAAEUGFpbAAAABIAAAAAAAAAADod3qn4ADkZM7Zsmoo3+FsF9Zw6HY7DxydNjeIgUVU8AAAAAwACsj8AAAAAAAAABgAAAAHX/kS9CvEdYCsQkfL0ofTfIS1ETQMh6jKts8wcu6sKBAAAABQAAAABABvFygAAAAAAAAXIAAAAAAADnrgAAAABIFFVPAAAAEBbcalx54eMMHwWJz7tzgOoxIVmMl4pexbgwTLzxnyMtAhZ2nZlsF18jIMDBaubSNSNPi4YRHkSajpyOcdZOzsCAAAAAAAAAAEB2EBTAAAAQDOlpIeUB73BImAZJCSAt0cuKZXHlKG+TJ+j+fCeFe9bDc5wHzMlDjU6YlB6geCuxRi7QwTq4RgxrOIJ9HICfg8="
    private static let pubnetFeeBumpHash = "5906453d5a367b4a8a1af9bbbc934904841718ec1ca1345874904e15f97bf83b"

    private static let testnetV1XDR =
        "AAAAAgAAAAAJDqKNhO2/XZAvmR1Wynm2lxfIUQwB6TDzqNVOlQgQTgAAm74AJGh0ABKiOwAAAAEAAAAAAAAAAAAAAABqgthtAAAAAAAAAAEAAAAAAAAAGAAAAAAAAAABmtIg9IzJFxPz3yuidCMj3LiE2SB3XYOl8DvtohHRPVAAAAAJc2V0X3ByaWNlAAAAAAAAAwAAABIAAAAAAAAAAAkOoo2E7b9dkC+ZHVbKebaXF8hRDAHpMPOo1U6VCBBOAAAADwAAAAZFVEhVU0QAAAAAAAoAAAAAAAAAAAAAAARomVswAAAAAQAAAAAAAAAAAAAAAZrSIPSMyRcT898ronQjI9y4hNkgd12DpfA77aIR0T1QAAAACXNldF9wcmljZQAAAAAAAAMAAAASAAAAAAAAAAAJDqKNhO2/XZAvmR1Wynm2lxfIUQwB6TDzqNVOlQgQTgAAAA8AAAAGRVRIVVNEAAAAAAAKAAAAAAAAAAAAAAAEaJlbMAAAAAAAAAABAAAAAAAAAAQAAAAGAAAAAcbgeSm1T8h+V5r+/0u+qUVZIopr5hDeGKj1+u37faSgAAAAEAAAAAEAAAADAAAADwAAAAdIYXNSb2xlAAAAABIAAAAAAAAAAAkOoo2E7b9dkC+ZHVbKebaXF8hRDAHpMPOo1U6VCBBOAAAADwAAAAZPUkFDTEUAAAAAAAEAAAAGAAAAAcbgeSm1T8h+V5r+/0u+qUVZIopr5hDeGKj1+u37faSgAAAAFAAAAAEAAAAHve3Sc2JfmD0Hu+w96oFCzEX1XxFR0uE/NeSf2Vqmia8AAAAH4IWMslKp5yCKjCiGPIRV6yV0LdrLOEfRrCRSwjur0G8AAAABAAAABgAAAAGa0iD0jMkXE/PfK6J0IyPcuITZIHddg6XwO+2iEdE9UAAAABQAAAABADikCAAAAAAAAAJUAAAAAAAATa0AAAABlQgQTgAAAEDSMm2vdKNsB2TCk+Pbb6vSYgq6Zd5F0E4H5BfMi4lwWEcYFAq2Mp+e12wr1qU+Ni7+2BTqZUkb+uK7lVM8PqkN"
    private static let testnetV1Hash = "c9b2d35ab15c055acb422872a8f1680a84ad6b8ad0d56271cfb74c083edf2007"

    // ENVELOPE_TYPE_TX_V0 (discriminant 0) — exercises the include-leading-zeros path.
    // Hash cross-checked against @stellar/stellar-sdk's Transaction.hash().
    private static let pubnetV0XDR =
        "AAAAAG5btGuvFysDlQ/whfTBH8NWx1qRgzGpjtSDnJx3krOBAAAAZAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAsAAAAAAAAAZAAAAAAAAAABd5KzgQAAAEAu0xW2vwIqtuAu4/FFLWHBooGpvqn/N6iHgEX45savBk7SyoFGKIlyhG7ETZQ93tbF1OC/5ym6SdXmwIhIPQUD"
    private static let pubnetV0Hash = "5b709eff53cb92c20d2c79e007f6b53ba9be04d6073119d142ffa70d7ea5c7cb"

    // MARK: - Helpers

    private func makeSignXDRResponse(signedXDR: String) -> RPCResult {
        // Production shape: RPCResult.response holds the already-unwrapped result value
        // (the JSON-RPC "result" key is stripped during RPCResponse decoding), matching
        // how the wallet builds the response — no enclosing "result" wrapper.
        let payload: [String: Any] = [
            "signedXDR": signedXDR,
            "signerAddress": "stellar:pubnet:GCXLMCYH2MGCT5RE6VLVZVQTZDNUACN3ETLZGEY6GN3PLA7ATNSPGGJH"
        ]
        return .response(AnyCodable(any: payload))
    }

    private func makeParams(chain: String?) -> AnyCodable {
        var params: [String: Any] = ["xdr": "...", "account": "stellar:pubnet:G..."]
        if let chain = chain {
            params["chain"] = chain
        }
        return AnyCodable(any: params)
    }

    // MARK: - Method Support Tests

    func testSupportsMethod() {
        XCTAssertTrue(stellarCollector.supportsMethod("stellar_signXDR"))
        XCTAssertTrue(stellarCollector.supportsMethod("stellar_signAndSubmitXDR"))
        XCTAssertFalse(stellarCollector.supportsMethod("stellar_signMessage"))
        XCTAssertFalse(stellarCollector.supportsMethod("eth_sendTransaction"))
    }

    // MARK: - Transaction Hash Parsing Tests

    func testParseTxHashes_SignXDR_PubnetV1() {
        let rpcResult = makeSignXDRResponse(signedXDR: Self.pubnetV1XDR)

        let hashes = stellarCollector.parseTxHashes(
            rpcMethod: StellarTVFCollector.STELLAR_SIGN_XDR,
            rpcResult: rpcResult,
            rpcParams: makeParams(chain: "stellar:pubnet")
        )

        XCTAssertEqual(hashes, [Self.pubnetV1Hash])
    }

    func testParseTxHashes_SignXDR_DefaultsToPubnet() {
        let rpcResult = makeSignXDRResponse(signedXDR: Self.pubnetV1XDR)

        let hashes = stellarCollector.parseTxHashes(
            rpcMethod: StellarTVFCollector.STELLAR_SIGN_XDR,
            rpcResult: rpcResult,
            rpcParams: makeParams(chain: nil)
        )

        XCTAssertEqual(hashes, [Self.pubnetV1Hash])
    }

    func testParseTxHashes_SignXDR_FeeBump_YieldsCanonicalFeeBumpHash() {
        let rpcResult = makeSignXDRResponse(signedXDR: Self.pubnetFeeBumpXDR)

        let hashes = stellarCollector.parseTxHashes(
            rpcMethod: StellarTVFCollector.STELLAR_SIGN_XDR,
            rpcResult: rpcResult,
            rpcParams: makeParams(chain: "stellar:pubnet")
        )

        XCTAssertEqual(hashes, [Self.pubnetFeeBumpHash])
    }

    func testParseTxHashes_SignXDR_Testnet() {
        let rpcResult = makeSignXDRResponse(signedXDR: Self.testnetV1XDR)

        let hashes = stellarCollector.parseTxHashes(
            rpcMethod: StellarTVFCollector.STELLAR_SIGN_XDR,
            rpcResult: rpcResult,
            rpcParams: makeParams(chain: "stellar:testnet")
        )

        XCTAssertEqual(hashes, [Self.testnetV1Hash])
    }

    func testParseTxHashes_SignXDR_V0Envelope() {
        let rpcResult = makeSignXDRResponse(signedXDR: Self.pubnetV0XDR)

        let hashes = stellarCollector.parseTxHashes(
            rpcMethod: StellarTVFCollector.STELLAR_SIGN_XDR,
            rpcResult: rpcResult,
            rpcParams: makeParams(chain: "stellar:pubnet")
        )

        XCTAssertEqual(hashes, [Self.pubnetV0Hash])
    }

    func testParseTxHashes_SignAndSubmitXDR_ExtractsTxHash() {
        let payload: [String: Any] = [
            "tx_hash": "6da5298ae2b4fd1567fa3f760e66c9fb9014e3ac72bf48af1ad8120f8423b961",
            "signedXDR": "AAAAAg==",
            "successful": true
        ]
        let rpcResult = RPCResult.response(AnyCodable(any: payload))

        let hashes = stellarCollector.parseTxHashes(
            rpcMethod: StellarTVFCollector.STELLAR_SIGN_AND_SUBMIT_XDR,
            rpcResult: rpcResult,
            rpcParams: nil
        )

        XCTAssertEqual(hashes, ["6da5298ae2b4fd1567fa3f760e66c9fb9014e3ac72bf48af1ad8120f8423b961"])
    }

    func testParseTxHashes_MalformedEnvelope_ReturnsNil() {
        let rpcResult = makeSignXDRResponse(signedXDR: "q83vASNFZ4mrze8BI0VniavN7wEjRWeJq83vAQ==")

        let hashes = stellarCollector.parseTxHashes(
            rpcMethod: StellarTVFCollector.STELLAR_SIGN_XDR,
            rpcResult: rpcResult,
            rpcParams: makeParams(chain: "stellar:pubnet")
        )

        XCTAssertNil(hashes)
    }

    func testParseTxHashes_ErrorResult_ReturnsNil() {
        let rpcResult = RPCResult.error(JSONRPCError(code: 4001, message: "User rejected"))

        let hashes = stellarCollector.parseTxHashes(
            rpcMethod: StellarTVFCollector.STELLAR_SIGN_XDR,
            rpcResult: rpcResult,
            rpcParams: makeParams(chain: "stellar:pubnet")
        )

        XCTAssertNil(hashes)
    }
}
