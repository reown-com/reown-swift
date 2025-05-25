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
        guard let result = rpcResult,
              case let .response(response) = result,
              let responseValue = response.value as? [String: [String]] else { // Updated to handle nested structure
            return nil
        }

        // Extract the array of signed transactions
        guard let signedTxnsBase64 = responseValue["result"] else {
            return nil
        }
        
        // Calculate transaction IDs
        return calculateTransactionIDs(from: signedTxnsBase64)
    }
    

    private func calculateTransactionIDs(from signedTxnsBase64: [String]) -> [String] {
        return signedTxnsBase64.compactMap { signedTxnBase64 -> String? in
            // Step 1: Decode the base64-encoded signed transaction
            guard let signedTxnBytes = Data(base64Encoded: signedTxnBase64) else {
                return nil
            }
            
            // Step 2: Parse the MessagePack to extract the "txn" field
            guard let canonicalTxnBytes = extractCanonicalTransaction(signedTxnBytes) else {
                return nil
            }
            
            // Step 3: Prefix with "TX"
            let prefix = "TX".data(using: .ascii)!
            let prefixedBytes = prefix + canonicalTxnBytes
            
            // Step 4: Compute SHA-512/256 hash
            let digest = SHA512.hash(data: prefixedBytes) // Use SHA512 directly
            let hash = Data(digest.prefix(32)) // SHA-512/256 means taking the first 256 bits (32 bytes) of SHA512
            
            // Step 5: Convert to Base32
            return Base32.encode(hash)
        }
    }

    private func extractCanonicalTransaction(_ signedTxnBytes: Data) -> Data? {
        do {
            // The signed transaction should be a map
            guard let unpackedValue = try signedTxnBytes.unpack() else {
                print("Failed to unpack signed transaction")
                return nil
            }
            
            guard let signedTxnMap = unpackedValue as? [String: Any?] else {
                print("Signed transaction is not a map of [String: Any?]")
                return nil
            }
            
            // Extract the "txn" field
            guard let txnValue = signedTxnMap["txn"] else {
                print("No 'txn' field found in signed transaction")
                return nil
            }
            
            // Re-encode just the txn part as MessagePack
            var packedTxnData = Data()
            try packedTxnData.pack(txnValue)
            return packedTxnData
        } catch {
            print("Failed to parse signed transaction MessagePack: \(error)")
            return nil
        }
    }
} 
