import Foundation
import CryptoKit

// MARK: - CosmosTVFCollector

class CosmosTVFCollector: ChainTVFCollector {
    // MARK: Constants
    static let COSMOS_SIGN_DIRECT = "cosmos_signDirect"
    static let COSMOS_SIGN_AMINO  = "cosmos_signAmino"
    static let COSMOS_SEND_TRANSACTION = "cosmos_sendTransaction"
    
    private var supportedMethods: [String] {
        [Self.COSMOS_SIGN_DIRECT, Self.COSMOS_SIGN_AMINO, Self.COSMOS_SEND_TRANSACTION]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        supportedMethods.contains(method)
    }
    
    // No contract addresses for Cosmos
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? { nil }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else { return nil }
        guard supportedMethods.contains(rpcMethod) else { return nil }
        // cosmos_sendTransaction returns raw hash string
        if rpcMethod == Self.COSMOS_SEND_TRANSACTION {
            if let rawHash = try? anycodable.get(String.self) {
                return [rawHash]
            }
            return nil
        }
        // For signDirect / signAmino we expect { result: { ... } }
        guard let wrapper = try? anycodable.get([String: AnyCodable].self),
              let resultAny = wrapper["result"],
              let result = try? resultAny.get([String: AnyCodable].self) else { return nil }
        switch rpcMethod {
        case Self.COSMOS_SIGN_DIRECT:
            return handleSignDirect(result)
        case Self.COSMOS_SIGN_AMINO:
            return handleSignAmino(result)
        default:
            return nil
        }
    }
    
    // MARK: - Private helpers
    private func handleSignDirect(_ result: [String: AnyCodable]) -> [String]? {
        guard let signatureAny = result["signature"],
              let signatureMap = try? signatureAny.get([String: AnyCodable].self),
              let sigBase64Any = signatureMap["signature"],
              let sigBase64 = try? sigBase64Any.get(String.self),
              let signedAny = result["signed"],
              let signedMap = try? signedAny.get([String: AnyCodable].self),
              let bodyAny = signedMap["bodyBytes"],
              let bodyB64 = try? bodyAny.get(String.self),
              let authAny = signedMap["authInfoBytes"],
              let authB64 = try? authAny.get(String.self) else { return nil }
        guard let bodyBytes = Data(base64Encoded: bodyB64),
              let authBytes = Data(base64Encoded: authB64),
              let sigBytes  = Data(base64Encoded: sigBase64) else { return nil }
        // Assemble TxRaw = bodyBytes || authInfoBytes || signatures (concatenated) as per protobuf order.
        var raw = Data()
        raw.append(bodyBytes)
        raw.append(authBytes)
        raw.append(sigBytes)
        let digest = sha256Hex(raw)
        return [digest]
    }
    
    private func handleSignAmino(_ result: [String: AnyCodable]) -> [String]? {
        guard let signatureAny = result["signature"],
              let signature = try? signatureAny.get([String: AnyCodable].self),
              let signedDocAny = result["signed"],
              let signedDoc = try? signedDocAny.get([String: AnyCodable].self) else { return nil }
        // Build StdTx dict
        var stdTx = [String: Any]()
        stdTx["msg"] = (signedDoc["msgs"]?.value) ?? []
        stdTx["fee"] = signedDoc["fee"]?.value ?? [:]
        stdTx["signatures"] = [signature.mapValues { $0.value }]
        stdTx["memo"] = signedDoc["memo"]?.value ?? ""
        guard let jsonData = try? JSONSerialization.data(withJSONObject: stdTx, options: [.sortedKeys]) else { return nil }
        let digest = sha256Hex(jsonData)
        return [digest]
    }
    
    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02X", $0) }.joined()
    }
} 