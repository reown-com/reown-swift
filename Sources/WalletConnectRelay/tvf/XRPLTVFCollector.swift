import Foundation

// MARK: - Supporting Model

struct XRPLSignTransactionResult: Codable {
    struct TxJson: Codable {
        let hash: String
        
        // Add other fields as needed, but we only care about the hash for TVF
        private enum CodingKeys: String, CodingKey {
            case hash
        }
    }
    
    let tx_json: TxJson
    
    private enum CodingKeys: String, CodingKey {
        case tx_json = "tx_json"
    }
}

// MARK: - XRPLTVFCollector

class XRPLTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let XRPL_SIGN_TRANSACTION = "xrpl_signTransaction"
    static let XRPL_SIGN_TRANSACTION_FOR = "xrpl_signTransactionFor"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.XRPL_SIGN_TRANSACTION, Self.XRPL_SIGN_TRANSACTION_FOR]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // XRPL doesn't use contract addresses in the TVF implementation
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process XRPL sign transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }
        
        // Extract from result wrapper (nested format)
        if let result = try? anycodable.get([String: AnyCodable].self),
           let resultValue = result["result"],
           let decoded = try? resultValue.get(XRPLSignTransactionResult.self) {
            return [decoded.tx_json.hash]
        }
        
        return nil
    }
} 