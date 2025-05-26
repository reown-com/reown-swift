import Foundation
import CryptoKit

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
        guard let result = rpcResult else {
            return nil
        }
        
        guard case let .response(response) = result else {
            return nil
        }
        
        // Get the underlying value from AnyCodable
        let underlyingValue: Any
        if let anyCodable = response.value as? AnyCodable {
            underlyingValue = anyCodable.value
        } else {
            underlyingValue = response.value
        }
        
        // Extract the "result" field from JSON-RPC response structure
        guard let responseDict = underlyingValue as? [String: Any],
              let signedTxnsBase64 = responseDict["result"] as? [String] else {
            return nil
        }
        
        // Calculate transaction IDs
        return calculateTransactionIDs(from: signedTxnsBase64)
    }
    

    private func calculateTransactionIDs(from signedTxnsBase64: [String]) -> [String] {
        let results = signedTxnsBase64.enumerated().compactMap { (index, signedTxnBase64) -> String? in
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
            let hash = SHA512_256.hash(data: prefixedBytes)
            
            // Step 5: Convert to Base32
            let base32Result = Base32Encoder.encode(hash)
            
            return base32Result
        }
        
        return results
    }

    private func extractCanonicalTransaction(_ signedTxnBytes: Data) -> Data? {
        // Manual MessagePack parsing to extract "txn" field without converting to Swift types
        return extractTxnFieldManually(from: signedTxnBytes)
    }
    
    private func extractTxnFieldManually(from data: Data) -> Data? {
        var index = 0
        
        // Read the first byte to determine the type
        guard index < data.count else { return nil }
        let firstByte = data[index]
        index += 1
        
        // We expect a map (dictionary)
        var mapSize: Int
        
        if firstByte >= 0x80 && firstByte <= 0x8f {
            // fixmap (0x80 - 0x8f): map with N elements (N = firstByte - 0x80)
            mapSize = Int(firstByte - 0x80)
        } else if firstByte == 0xde {
            // map 16: next 2 bytes are size
            guard index + 1 < data.count else { return nil }
            mapSize = Int(data[index]) << 8 | Int(data[index + 1])
            index += 2
        } else if firstByte == 0xdf {
            // map 32: next 4 bytes are size
            guard index + 3 < data.count else { return nil }
            mapSize = Int(data[index]) << 24 | Int(data[index + 1]) << 16 | Int(data[index + 2]) << 8 | Int(data[index + 3])
            index += 4
        } else {
            return nil
        }
        
        // Look for the "txn" key
        for _ in 0..<mapSize {
            // Read the key
            guard let (keyData, keyEndIndex) = readMessagePackValue(from: data, startIndex: index) else {
                return nil
            }
            index = keyEndIndex
            
            // Check if this key is "txn"
            if let keyString = parseStringFromMessagePack(keyData) {
                if keyString == "txn" {
                    // Read and return the value
                    guard let (valueData, _) = readMessagePackValue(from: data, startIndex: index) else {
                        return nil
                    }
                    return valueData
                }
            }
            
            // Skip the value for this key
            guard let (_, valueEndIndex) = readMessagePackValue(from: data, startIndex: index) else {
                return nil
            }
            index = valueEndIndex
        }
        
        return nil
    }
    
    private func readMessagePackValue(from data: Data, startIndex: Int) -> (Data, Int)? {
        guard startIndex < data.count else { return nil }
        
        let startByte = data[startIndex]
        var endIndex = startIndex + 1
        
        // Determine the length based on MessagePack format
        switch startByte {
        // Positive fixint (0x00 - 0x7f)
        case 0x00...0x7f:
            break
            
        // Negative fixint (0xe0 - 0xff)  
        case 0xe0...0xff:
            break
            
        // fixstr (0xa0 - 0xbf)
        case 0xa0...0xbf:
            let strLength = Int(startByte - 0xa0)
            endIndex += strLength
            
        // fixmap (0x80 - 0x8f)
        case 0x80...0x8f:
            let mapSize = Int(startByte - 0x80)
            // Read all key-value pairs
            for _ in 0..<mapSize {
                guard let (_, keyEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = keyEnd
                guard let (_, valueEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = valueEnd
            }
            
        // fixarray (0x90 - 0x9f)
        case 0x90...0x9f:
            let arraySize = Int(startByte - 0x90)
            for _ in 0..<arraySize {
                guard let (_, itemEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = itemEnd
            }
            
        // nil (0xc0)
        case 0xc0:
            break
            
        // false (0xc2)
        case 0xc2:
            break
            
        // true (0xc3)
        case 0xc3:
            break
            
        // bin 8 (0xc4)
        case 0xc4:
            guard endIndex < data.count else { return nil }
            let binLength = Int(data[endIndex])
            endIndex += 1 + binLength
            
        // bin 16 (0xc5)
        case 0xc5:
            guard endIndex + 1 < data.count else { return nil }
            let binLength = Int(data[endIndex]) << 8 | Int(data[endIndex + 1])
            endIndex += 2 + binLength
            
        // bin 32 (0xc6)
        case 0xc6:
            guard endIndex + 3 < data.count else { return nil }
            let binLength = Int(data[endIndex]) << 24 | Int(data[endIndex + 1]) << 16 | Int(data[endIndex + 2]) << 8 | Int(data[endIndex + 3])
            endIndex += 4 + binLength
            
        // float 32 (0xca)
        case 0xca:
            endIndex += 4
            
        // float 64 (0xcb)
        case 0xcb:
            endIndex += 8
            
        // uint 8 (0xcc)
        case 0xcc:
            endIndex += 1
            
        // uint 16 (0xcd)
        case 0xcd:
            endIndex += 2
            
        // uint 32 (0xce)
        case 0xce:
            endIndex += 4
            
        // uint 64 (0xcf)
        case 0xcf:
            endIndex += 8
            
        // int 8 (0xd0)
        case 0xd0:
            endIndex += 1
            
        // int 16 (0xd1)
        case 0xd1:
            endIndex += 2
            
        // int 32 (0xd2)
        case 0xd2:
            endIndex += 4
            
        // int 64 (0xd3)
        case 0xd3:
            endIndex += 8
            
        // str 8 (0xd9)
        case 0xd9:
            guard endIndex < data.count else { return nil }
            let strLength = Int(data[endIndex])
            endIndex += 1 + strLength
            
        // str 16 (0xda)
        case 0xda:
            guard endIndex + 1 < data.count else { return nil }
            let strLength = Int(data[endIndex]) << 8 | Int(data[endIndex + 1])
            endIndex += 2 + strLength
            
        // str 32 (0xdb)
        case 0xdb:
            guard endIndex + 3 < data.count else { return nil }
            let strLength = Int(data[endIndex]) << 24 | Int(data[endIndex + 1]) << 16 | Int(data[endIndex + 2]) << 8 | Int(data[endIndex + 3])
            endIndex += 4 + strLength
            
        // array 16 (0xdc)
        case 0xdc:
            guard endIndex + 1 < data.count else { return nil }
            let arraySize = Int(data[endIndex]) << 8 | Int(data[endIndex + 1])
            endIndex += 2
            for _ in 0..<arraySize {
                guard let (_, itemEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = itemEnd
            }
            
        // array 32 (0xdd)
        case 0xdd:
            guard endIndex + 3 < data.count else { return nil }
            let arraySize = Int(data[endIndex]) << 24 | Int(data[endIndex + 1]) << 16 | Int(data[endIndex + 2]) << 8 | Int(data[endIndex + 3])
            endIndex += 4
            for _ in 0..<arraySize {
                guard let (_, itemEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = itemEnd
            }
            
        // map 16 (0xde)
        case 0xde:
            guard endIndex + 1 < data.count else { return nil }
            let mapSize = Int(data[endIndex]) << 8 | Int(data[endIndex + 1])
            endIndex += 2
            for _ in 0..<mapSize {
                guard let (_, keyEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = keyEnd
                guard let (_, valueEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = valueEnd
            }
            
        // map 32 (0xdf)
        case 0xdf:
            guard endIndex + 3 < data.count else { return nil }
            let mapSize = Int(data[endIndex]) << 24 | Int(data[endIndex + 1]) << 16 | Int(data[endIndex + 2]) << 8 | Int(data[endIndex + 3])
            endIndex += 4
            for _ in 0..<mapSize {
                guard let (_, keyEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = keyEnd
                guard let (_, valueEnd) = readMessagePackValue(from: data, startIndex: endIndex) else { return nil }
                endIndex = valueEnd
            }
            
        default:
            return nil
        }
        
        guard endIndex <= data.count else { return nil }
        return (data.subdata(in: startIndex..<endIndex), endIndex)
    }
    
    private func parseStringFromMessagePack(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        
        let firstByte = data[0]
        var stringData: Data
        
        if firstByte >= 0xa0 && firstByte <= 0xbf {
            // fixstr
            let length = Int(firstByte - 0xa0)
            guard data.count >= 1 + length else { return nil }
            stringData = data.subdata(in: 1..<(1 + length))
        } else if firstByte == 0xd9 {
            // str 8
            guard data.count >= 2 else { return nil }
            let length = Int(data[1])
            guard data.count >= 2 + length else { return nil }
            stringData = data.subdata(in: 2..<(2 + length))
        } else {
            return nil
        }
        
        return String(data: stringData, encoding: .utf8)
    }
} 
