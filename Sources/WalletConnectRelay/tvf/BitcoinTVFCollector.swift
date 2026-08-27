import Foundation

// MARK: - Supporting Model

struct BitcoinTransferResult: Codable {
    let txid: String
    
    private enum CodingKeys: String, CodingKey {
        case txid
    }
}

// MARK: - BitcoinTVFCollector

class BitcoinTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let BITCOIN_SEND_TRANSFER = "sendTransfer"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.BITCOIN_SEND_TRANSFER]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // Bitcoin doesn't use contracts in the same way as EVM chains
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process Bitcoin transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }
        
        // Decode directly from the unwrapped result value
        if let t = try? anycodable.get(BitcoinTransferResult.self) {
            return [t.txid]
        }

        // Alternative: try to extract txid directly from the result map if the above fails
        if let map = try? anycodable.get([String: AnyCodable].self),
           let v = map["txid"],
           let txid = try? v.get(String.self) {
            return [txid]
        }

        return nil
    }
} 