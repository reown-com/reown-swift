import Foundation
import CryptoKit

// MARK: - Base32 Encoder

private struct Base32 {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    
    static func encode(_ data: Data) -> String {
        var result = ""
        var bits = 0
        var buffer = 0
        
        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            
            while bits >= 5 {
                bits -= 5
                let index = (buffer >> bits) & 0x1F
                result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
            }
        }
        
        if bits > 0 {
            let index = (buffer << (5 - bits)) & 0x1F
            result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
        }
        
        return result
    }
}

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
        
        // Extract from result wrapper (always under "result" key in JSON-RPC)
        if let result = try? anycodable.get([String: AnyCodable].self),
           let resultValue = result["result"],
           let signedTxnsArray = try? resultValue.get([String].self) {
            return calculateTransactionIDs(from: signedTxnsArray)
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Calculates Algorand transaction IDs from an array of base64-encoded signed transactions
    ///
    /// The algorithm follows these steps:
    /// 1. Decode base64 to raw bytes
    /// 2. Compute SHA-512/256 hash of the bytes (using the first 32 bytes of SHA-512)
    /// 3. Compute checksum (last 4 bytes of SHA-512/256 of the hash)
    /// 4. Combine hash+checksum and encode to base32
    private func calculateTransactionIDs(from signedTxnsBase64: [String]) -> [String] {
        // Filter out null/empty values
        let validSignedTxns = signedTxnsBase64.filter { !$0.isEmpty && $0 != "null" }
        
        return validSignedTxns.compactMap { base64Str in
            // Step 1: Decode base64 to raw bytes
            guard let signedTxnData = Data(base64Encoded: base64Str) else {
                return nil
            }
            
            // Step 2: Compute SHA-512/256 hash (using first 32 bytes of SHA-512)
            let sha512Hash = SHA512.hash(data: signedTxnData)
            let sha512HashData = Data(sha512Hash)
            // Take first 32 bytes to simulate SHA-512/256
            let hashData = sha512HashData.prefix(32)
            
            // Step 3: Compute checksum (last 4 bytes of SHA-512/256 of the hash)
            let checksumHash = SHA512.hash(data: hashData)
            let checksumHashData = Data(checksumHash)
            let checksum = checksumHashData.suffix(4)
            
            // Step 4: Combine hash+checksum and encode to base32
            let txIDData = hashData + checksum
            return Base32.encode(txIDData)
        }
    }
} 