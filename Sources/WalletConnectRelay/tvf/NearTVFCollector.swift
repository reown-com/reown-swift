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
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process NEAR transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }
        
        // The anycodable.value might be nested AnyCodable, so we need to extract the actual dictionary
        var actualValue: Any = anycodable.value
        
        // If the value is another AnyCodable, extract its value
        if let nestedAnyCodable = anycodable.value as? AnyCodable {
            actualValue = nestedAnyCodable.value
        }
        
        // Try to parse as dictionary with "result" key
        if let resultDict = actualValue as? [String: Any],
           let resultValue = resultDict["result"] {
            
            // Check if resultValue is already an AnyCodable or a raw value
            let resultAnyCodable: AnyCodable
            if let existingAnyCodable = resultValue as? AnyCodable {
                resultAnyCodable = existingAnyCodable
            } else {
                resultAnyCodable = AnyCodable(any: resultValue)
            }
            
            return processSingleResult(rpcMethod: rpcMethod, resultValue: resultAnyCodable)
        }
        
        // Fallback: Try to process the anycodable directly
        let directResult = processSingleResult(rpcMethod: rpcMethod, resultValue: anycodable)
        if directResult != nil {
            return directResult
        }
        
        return nil
    }
    
    private func processSingleResult(rpcMethod: String, resultValue: AnyCodable) -> [String]? {
        if rpcMethod == Self.NEAR_SIGN_TRANSACTION {
            if let txData = extractTransactionData(from: resultValue) {
                let hash = calculateTransactionHash(from: txData)
                return [hash]
            }
        } else if rpcMethod == Self.NEAR_SIGN_TRANSACTIONS {
            if let txArray = try? resultValue.get([AnyCodable].self) {
                let hashes = txArray.compactMap { txElement -> String? in
                    guard let txData = extractTransactionData(from: txElement) else { return nil }
                    return calculateTransactionHash(from: txData)
                }
                return hashes.isEmpty ? nil : hashes
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Extracts transaction data from either a UInt8 array or a Buffer-like object
    private func extractTransactionData(from element: AnyCodable) -> Data? {
        // First, let's check if element.value is a raw dictionary (from our parsing above)
        if let rawDict = element.value as? [String: Any] {
            // Check if it's a Buffer object with data field
            if let dataArray = rawDict["data"] as? [Any] {
                // Convert the array to UInt8 array
                let uint8Array = dataArray.compactMap { item -> UInt8? in
                    if let intValue = item as? Int {
                        return UInt8(intValue & 0xFF)
                    } else if let doubleValue = item as? Double {
                        return UInt8(Int(doubleValue) & 0xFF)
                    }
                    return nil
                }
                
                if uint8Array.count == dataArray.count {
                    return Data(uint8Array)
                }
            }
            
            // Check if it's a JSON bytes array object (keys are string indices)
            // This handles the format: {"0": 16, "1": 0, "2": 0, ...}
            let sortedKeys = rawDict.keys.compactMap { Int($0) }.sorted()
            if !sortedKeys.isEmpty && sortedKeys.first == 0 && sortedKeys.count == rawDict.count {
                let uint8Array = sortedKeys.compactMap { index -> UInt8? in
                    guard let value = rawDict[String(index)] else { return nil }
                    if let intValue = value as? Int {
                        return UInt8(intValue & 0xFF)
                    } else if let doubleValue = value as? Double {
                        return UInt8(Int(doubleValue) & 0xFF)
                    }
                    return nil
                }
                
                if uint8Array.count == rawDict.count {
                    return Data(uint8Array)
                }
            }
        }
        
        // Check if element.value is another AnyCodable (nested case)
        if let nestedAnyCodable = element.value as? AnyCodable {
            return extractTransactionData(from: nestedAnyCodable)
        }
        
        // Try to decode as array of integers first (UInt8 array)
        if let intArray = try? element.get([Int].self) {
            let uint8Array = intArray.map { UInt8($0 & 0xFF) }
            return Data(uint8Array)
        }
        
        // Try to decode as array of UInt8 directly
        if let uint8Array = try? element.get([UInt8].self) {
            return Data(uint8Array)
        }
        
        // Try to decode as Buffer object with data field using AnyCodable.get
        if let bufferObj = try? element.get([String: AnyCodable].self),
           let dataField = bufferObj["data"] {
            
            // Try as [Int] first
            if let intArray = try? dataField.get([Int].self) {
                let uint8Array = intArray.map { UInt8($0 & 0xFF) }
                return Data(uint8Array)
            }
            
            // Try as [UInt8] second
            if let uint8Array = try? dataField.get([UInt8].self) {
                return Data(uint8Array)
            }
        }
        
        return nil
    }
    
    /// Calculates the NEAR transaction hash from signed transaction data
    /// According to NEAR docs: hash = base58(sha256(signedTransactionBytes))
    private func calculateTransactionHash(from txData: Data) -> String {
        let hash = txData.sha256()
        return Base58.encode(hash)
    }
} 
