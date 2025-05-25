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
        print("🔍 parseTxHashes called with method: \(rpcMethod)")
        print("🔍 rpcResult: \(String(describing: rpcResult))")
        
        guard let result = rpcResult else {
            print("❌ rpcResult is nil")
            return nil
        }
        
        guard case let .response(response) = result else {
            print("❌ rpcResult is not a response, it's: \(result)")
            return nil
        }
        
        print("🔍 response.value type: \(type(of: response.value))")
        print("🔍 response.value: \(response.value)")
        
        // Get the underlying value from AnyCodable
        var underlyingValue: Any
        if let anyCodable = response.value as? AnyCodable {
            underlyingValue = anyCodable.value
            print("🔍 Successfully cast to AnyCodable, underlyingValue type: \(type(of: underlyingValue))")
        } else {
            underlyingValue = response.value
            print("🔍 Using response.value directly as underlyingValue type: \(type(of: underlyingValue))")
        }
        print("🔍 underlyingValue: \(underlyingValue)")
        
        // Try different possible structures
        var signedTxnsBase64: [String]?
        
        // Option 1: Direct array
        if let directArray = underlyingValue as? [String] {
            print("✅ Found direct array of strings")
            signedTxnsBase64 = directArray
        }
        // Option 2: Nested with "result" key
        else if let responseDict = underlyingValue as? [String: [String]],
                let resultArray = responseDict["result"] {
            print("✅ Found nested structure with 'result' key")
            signedTxnsBase64 = resultArray
        }
        // Option 3: Any other nested structure
        else if let responseDict = underlyingValue as? [String: Any] {
            print("🔍 Found dictionary, keys: \(responseDict.keys)")
            if let resultArray = responseDict["result"] as? [String] {
                print("✅ Found 'result' key with string array")
                signedTxnsBase64 = resultArray
            }
        }
        // Option 4: Try with AnyHashable keys
        else if let responseDict = underlyingValue as? [AnyHashable: Any] {
            print("🔍 Found dictionary with AnyHashable keys: \(responseDict.keys)")
            if let resultArray = responseDict["result"] as? [String] {
                print("✅ Found 'result' key with string array (AnyHashable)")
                signedTxnsBase64 = resultArray
            }
        }
        
        guard let finalSignedTxnsBase64 = signedTxnsBase64 else {
            print("❌ Could not extract signed transactions array from response")
            return nil
        }
        
        print("🔍 Extracted signedTxnsBase64 count: \(finalSignedTxnsBase64.count)")
        for (index, txn) in finalSignedTxnsBase64.enumerated() {
            print("🔍 Transaction \(index): \(txn.prefix(50))...")
        }
        
        // Calculate transaction IDs
        let result_hashes = calculateTransactionIDs(from: finalSignedTxnsBase64)
        print("🔍 calculateTransactionIDs returned: \(result_hashes)")
        return result_hashes
    }
    

    private func calculateTransactionIDs(from signedTxnsBase64: [String]) -> [String] {
        print("🔍 calculateTransactionIDs called with \(signedTxnsBase64.count) transactions")
        
        let results = signedTxnsBase64.compactMap { signedTxnBase64 -> String? in
            print("🔍 Processing transaction: \(signedTxnBase64.prefix(50))...")
            
            // Step 1: Decode the base64-encoded signed transaction
            guard let signedTxnBytes = Data(base64Encoded: signedTxnBase64) else {
                print("❌ Failed to decode base64: \(signedTxnBase64.prefix(50))...")
                return nil
            }
            print("✅ Successfully decoded base64 to \(signedTxnBytes.count) bytes")
            
            // Step 2: Parse the MessagePack to extract the "txn" field
            guard let canonicalTxnBytes = extractCanonicalTransaction(signedTxnBytes) else {
                print("❌ Failed to extract canonical transaction")
                return nil
            }
            print("✅ Extracted canonical transaction: \(canonicalTxnBytes.count) bytes")
            
            // Step 3: Prefix with "TX"
            let prefix = "TX".data(using: .ascii)!
            let prefixedBytes = prefix + canonicalTxnBytes
            print("🔍 Prefixed bytes length: \(prefixedBytes.count)")
            
            // Step 4: Compute SHA-512/256 hash
            let digest = SHA512.hash(data: prefixedBytes)
            let hash = Data(digest.prefix(32)) // SHA-512/256 means taking the first 256 bits (32 bytes) of SHA512
            print("🔍 SHA512/256 hash: \(hash.map { String(format: "%02x", $0) }.joined())")
            
            // Step 5: Convert to Base32
            let base32Result = Base32.encode(hash)
            print("✅ Base32 result: \(base32Result)")
            return base32Result
        }
        
        print("🔍 Final results: \(results)")
        return results
    }

    private func extractCanonicalTransaction(_ signedTxnBytes: Data) -> Data? {
        print("Attempting to extract canonical transaction from: \(signedTxnBytes.base64EncodedString())")
        
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
            print("❌ Expected map, got: 0x\(String(format: "%02x", firstByte))")
            return nil
        }
        
        print("🔍 Map has \(mapSize) entries")
        
        // Look for the "txn" key
        for _ in 0..<mapSize {
            // Read the key
            guard let (keyData, keyEndIndex) = readMessagePackValue(from: data, startIndex: index) else {
                print("❌ Failed to read key")
                return nil
            }
            index = keyEndIndex
            
            // Check if this key is "txn"
            if let keyString = parseStringFromMessagePack(keyData), keyString == "txn" {
                print("✅ Found 'txn' key")
                // Read and return the value
                guard let (valueData, _) = readMessagePackValue(from: data, startIndex: index) else {
                    print("❌ Failed to read 'txn' value")
                    return nil
                }
                print("✅ Extracted 'txn' value: \(valueData.count) bytes")
                return valueData
            } else {
                // Skip the value for this key
                guard let (_, valueEndIndex) = readMessagePackValue(from: data, startIndex: index) else {
                    print("❌ Failed to skip value")
                    return nil
                }
                index = valueEndIndex
            }
        }
        
        print("❌ 'txn' key not found in map")
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
            print("❌ Unsupported MessagePack type: 0x\(String(format: "%02x", startByte))")
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
