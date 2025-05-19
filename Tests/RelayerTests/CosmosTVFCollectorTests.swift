import XCTest
import CryptoKit
@testable import WalletConnectRelay

// Mock helpers
enum CosmosMock {
    static func signDirectResult(bodyB64: String, authB64: String, sigB64: String) -> [String: Any] {
        return [
            "signature": [
                "signature": sigB64
            ],
            "signed": [
                "bodyBytes": bodyB64,
                "authInfoBytes": authB64
            ]
        ]
    }
    
    static func signAminoResult(signedDoc: [String: Any], signature: [String: Any]) -> [String: Any] {
        return [
            "signature": signature,
            "signed": signedDoc
        ]
    }
}

final class CosmosTVFCollectorTests: XCTestCase {
    private let collector = CosmosTVFCollector()
    
    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map{String(format: "%02X", $0)}.joined()
    }
    
    func testParseTxHashes_SignDirect() {
        let body = Data([0x01,0x02])
        let auth = Data([0x03])
        let sig  = Data([0x04])
        let bodyB64 = body.base64EncodedString()
        let authB64 = auth.base64EncodedString()
        let sigB64  = sig.base64EncodedString()
        var raw = Data()
        raw.append(body)
        raw.append(auth)
        raw.append(sig)
        let expected = sha256Hex(raw)
        let resultObj = CosmosMock.signDirectResult(bodyB64: bodyB64, authB64: authB64, sigB64: sigB64)
        let rpcResult = RPCResult.response(AnyCodable(any: ["result": resultObj]))
        let hashes = collector.parseTxHashes(rpcMethod: "cosmos_signDirect", rpcResult: rpcResult)
        XCTAssertEqual(hashes, [expected])
    }
    
    func testParseTxHashes_SignAmino() {
        let signature: [String: Any] = ["signature": "AAAA"]
        let signedDoc: [String: Any] = [
            "memo": "",
            "msgs": [],
            "fee": [:]
        ]
        let resultObj = CosmosMock.signAminoResult(signedDoc: signedDoc, signature: signature)
        let stdTx = ["msg":[],"fee":[:],"signatures":[signature],"memo":""] as [String:Any]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: stdTx, options: [.sortedKeys]) else { XCTFail(); return }
        let expected = sha256Hex(jsonData)
        let rpcResult = RPCResult.response(AnyCodable(any: ["result": resultObj]))
        let hashes = collector.parseTxHashes(rpcMethod: "cosmos_signAmino", rpcResult: rpcResult)
        XCTAssertEqual(hashes, [expected])
    }
} 