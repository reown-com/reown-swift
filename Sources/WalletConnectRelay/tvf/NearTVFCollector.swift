import Foundation

// MARK: - NearTVFCollector

class NearTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let NEAR_SIGN_TRANSACTION = "near_signTransaction"
    static let NEAR_SIGN_TRANSACTIONS = "near_signTransactions"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.NEAR_SIGN_TRANSACTION, Self.NEAR_SIGN_TRANSACTIONS]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // NEAR implementation doesn't extract contract addresses for TVF
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process NEAR transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }
        
        // Extract from result wrapper (always under "result" key in JSON-RPC)
        if let result = try? anycodable.get([String: AnyCodable].self),
           let resultValue = result["result"] {
            
            if rpcMethod == Self.NEAR_SIGN_TRANSACTION {
                // For near_signTransaction, the result is a single Uint8Array
                return extractTransactionHash(from: resultValue)
            } else if rpcMethod == Self.NEAR_SIGN_TRANSACTIONS {
                // For near_signTransactions, the result is an array of Uint8Array
                return extractTransactionHashes(from: resultValue)
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Extracts transaction hash from a single signed transaction data
    private func extractTransactionHash(from resultValue: AnyCodable) -> [String]? {
        // Try to extract the binary data from various representations
        if let uint8ArrayData = extractUint8ArrayData(from: resultValue) {
            // In NEAR, the transaction hash is the base58-encoded representation of the signed transaction
            let hash = Base58.encode(uint8ArrayData)
            return [hash]
        }
        return nil
    }
    
    /// Extracts transaction hashes from multiple signed transaction data
    private func extractTransactionHashes(from resultValue: AnyCodable) -> [String]? {
        if let array = try? resultValue.get([AnyCodable].self) {
            var hashes = [String]()
            for item in array {
                if let uint8ArrayData = extractUint8ArrayData(from: item) {
                    let hash = Base58.encode(uint8ArrayData)
                    hashes.append(hash)
                }
            }
            return hashes.isEmpty ? nil : hashes
        }
        return nil
    }
    
    /// Helper method to extract Uint8Array data from different representations
    private func extractUint8ArrayData(from anyCodable: AnyCodable) -> Data? {
        // Case 1: Directly as Data
        if let data = try? anyCodable.get(Data.self) {
            return data
        }
        
        // Case 2: As Array of integers (typical JS Uint8Array representation)
        if let intArray = try? anyCodable.get([Int].self) {
            let bytes = intArray.map { UInt8($0) }
            return Data(bytes)
        }
        
        // Case 3: As Dictionary with numeric keys (another common JS serialization)
        if let dict = try? anyCodable.get([String: AnyCodable].self) {
            var bytes = [UInt8]()
            var index = 0
            while let value = dict[String(index)], 
                  let intValue = try? value.get(Int.self),
                  intValue >= 0 && intValue <= 255 {
                bytes.append(UInt8(intValue))
                index += 1
            }
            return bytes.isEmpty ? nil : Data(bytes)
        }
        
        // Case 4: As base64 or hex string
        if let base64String = try? anyCodable.get(String.self) {
            if let data = Data(base64Encoded: base64String) {
                return data
            }
            
            if base64String.hasPrefix("0x"), 
               let data = Data(hexString: String(base64String.dropFirst(2))) {
                return data
            }
        }
        
        return nil
    }
}

// MARK: - Helper extension for hex conversion
fileprivate extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
} 