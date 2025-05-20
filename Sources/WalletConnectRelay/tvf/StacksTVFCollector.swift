import Foundation

// MARK: - Supporting Model

struct StacksTransferResult: Codable {
    let txId: String
    let txRaw: String
    
    private enum CodingKeys: String, CodingKey {
        case txId
        case txRaw
    }
}

// MARK: - StacksTVFCollector

class StacksTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let STACKS_STX_TRANSFER = "stacks_stxTransfer"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.STACKS_STX_TRANSFER]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // Stacks doesn't extract contract addresses for TVF in this implementation
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process Stacks transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }
        
        // Extract from result wrapper (always under "result" key in JSON-RPC)
        if let result = try? anycodable.get([String: AnyCodable].self),
           let resultValue = result["result"] {
            
            // Try to decode as StacksTransferResult
            if let transferResult = try? resultValue.get(StacksTransferResult.self) {
                return [transferResult.txId]
            }
        }
        
        return nil
    }
} 