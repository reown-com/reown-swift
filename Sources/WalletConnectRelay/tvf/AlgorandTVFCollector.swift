import Foundation

// MARK: - AlgorandTVFCollector

class AlgorandTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let ALGORAND_SIGN_TXN = "algo_signTxn"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.ALGORAND_SIGN_TXN]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // Algorand implementation doesn't collect contract addresses for TVF
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process Algorand transaction methods
        guard rpcMethod == Self.ALGORAND_SIGN_TXN else {
            return nil
        }
        
        // Extract from result wrapper
        if let result = try? anycodable.get([String: AnyCodable].self),
           let resultValue = result["result"] {
            // Try to get the array of base64 signed transactions
            if let signedTxnsArray = try? resultValue.get([String].self) {
                return calculateTransactionIDs(from: signedTxnsArray)
            }
        } else if let signedTxnsArray = try? anycodable.get([String].self) {
            // Direct array format
            return calculateTransactionIDs(from: signedTxnsArray)
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Calculates Algorand transaction IDs from an array of base64-encoded signed transactions
    /// 
    /// This is a placeholder implementation. In a real app, this would:
    /// 1. Decode each base64 string to bytes
    /// 2. Compute SHA-512/256 hash of the bytes
    /// 3. Compute checksum (last 4 bytes of SHA-512/256 of the hash)
    /// 4. Combine hash+checksum and encode to base32
    ///
    /// The actual implementation would depend on the available cryptographic libraries.
    private func calculateTransactionIDs(from signedTxnsBase64: [String]) -> [String] {
        // This is a mock implementation - in reality we would need to perform the actual 
        // cryptographic operations as described in the documentation
        
        // Filter out null/empty values
        let validSignedTxns = signedTxnsBase64.filter { !$0.isEmpty && $0 != "null" }
        
        // For testing purposes, return deterministic mock IDs based on the input
        return validSignedTxns.map { base64Str in
            // In a real implementation, this would be the proper cryptographic calculation
            // Here we just create a mock ID based on a hash of the base64 string
            let hashValue = abs(base64Str.hashValue)
            return "ALGO\(hashValue)"
        }
    }
} 