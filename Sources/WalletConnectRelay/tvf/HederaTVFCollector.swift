import Foundation

// MARK: - Supporting Model

struct HederaTransactionResult: Codable {
    let nodeId: String
    let transactionHash: String
    let transactionId: String
    
    private enum CodingKeys: String, CodingKey {
        case nodeId
        case transactionHash
        case transactionId
    }
}

// MARK: - HederaTVFCollector

class HederaTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let HEDERA_SIGN_AND_EXECUTE_TRANSACTION = "hedera_signAndExecuteTransaction"
    static let HEDERA_EXECUTE_TRANSACTION = "hedera_executeTransaction"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.HEDERA_SIGN_AND_EXECUTE_TRANSACTION, Self.HEDERA_EXECUTE_TRANSACTION]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // Hedera implementation doesn't collect contract addresses for TVF
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process Hedera transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }
        
        // Extract from result wrapper (nested format)
        if let result = try? anycodable.get([String: AnyCodable].self),
           let resultValue = result["result"],
           let decoded = try? resultValue.get(HederaTransactionResult.self) {
            return [decoded.transactionId]
        }
        
        return nil
    }
} 