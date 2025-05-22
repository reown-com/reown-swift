import Foundation

// MARK: - Supporting Model

struct SuiSignAndExecuteTransactionResult: Codable {
    let digest: String
    // Other fields (effects, events, etc.) could be added but are not needed for TVF
    
    private enum CodingKeys: String, CodingKey {
        case digest
    }
}

struct SuiSignTransactionResult: Codable {
    let signature: String
    let transactionBytes: String
    
    private enum CodingKeys: String, CodingKey {
        case signature
        case transactionBytes
    }
}

// MARK: - SuiTVFCollector

class SuiTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let SUI_SIGN_AND_EXECUTE_TRANSACTION = "sui_signAndExecuteTransaction"
    static let SUI_SIGN_TRANSACTION = "sui_signTransaction"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.SUI_SIGN_AND_EXECUTE_TRANSACTION, Self.SUI_SIGN_TRANSACTION]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // SUI implementation doesn't collect contract addresses for TVF
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process SUI transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }
        
        // Extract from result wrapper (always under "result" key in JSON-RPC)
        if let result = try? anycodable.get([String: AnyCodable].self),
           let resultValue = result["result"] {
            
            if rpcMethod == Self.SUI_SIGN_AND_EXECUTE_TRANSACTION {
                // For sui_signAndExecuteTransaction, extract digest directly
                if let signAndExecuteResult = try? resultValue.get(SuiSignAndExecuteTransactionResult.self) {
                    return [signAndExecuteResult.digest]
                }
            } else if rpcMethod == Self.SUI_SIGN_TRANSACTION {
                // For sui_signTransaction, we need to calculate the digest from transactionBytes
                if let signResult = try? resultValue.get(SuiSignTransactionResult.self) {
                    // In a real implementation, we would calculate the transaction digest
                    // from the transaction bytes using the Blake2b hash algorithm
                    // Here we're using the transactionBytes as a placeholder
                    if let digest = calculateTransactionDigest(from: signResult.transactionBytes) {
                        return [digest]
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Calculates a SUI transaction digest from base64-encoded transaction bytes
    private func calculateTransactionDigest(from transactionBytesBase64: String) -> String? {
        // Step 1: Decode base64 to raw bytes
        guard let txBytes = Data(base64Encoded: transactionBytesBase64) else {
            return nil
        }
        
        // Step 2: Prefix with "TransactionData::" (required for correct Sui digest calculation)
        let prefix = "TransactionData::"
        let prefixData = Data(prefix.utf8)
        
        var prefixedBytes = Data()
        prefixedBytes.append(prefixData)
        prefixedBytes.append(txBytes)
        
        // Step 3: Compute Blake2b-256 hash of the prefixed bytes
        // Use 32 bytes (256 bits) for the digest length
        guard let hashData = try? BLAKE2b.hash(data: prefixedBytes, digestLength: 32) else {
            return nil
        }
        
        // Step 4: Encode the result to base58
        return Base58.encode(hashData)
    }
}
