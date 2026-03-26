import Foundation

// MARK: - Supporting Models

struct PolkadotSignatureResponse: Codable {
    let id: Int?
    let signature: String
}

struct PolkadotTransactionPayload: Codable {
    let method: String
    let specVersion: String?
    let transactionVersion: String?
    let genesisHash: String?
    let blockHash: String?
    let era: String?
    let nonce: String?
    let tip: String?
    let mode: String?
    let metadataHash: String?
    let address: String?
    let version: Int?
    let blockNumber: String?
}

struct PolkadotRequestParams: Codable {
    let address: String?
    let transactionPayload: PolkadotTransactionPayload
}

// MARK: - PolkadotTVFCollector

class PolkadotTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let POLKADOT_SIGN_TRANSACTION = "polkadot_signTransaction"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.POLKADOT_SIGN_TRANSACTION]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // Polkadot implementation doesn't extract contract addresses for TVF
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process Polkadot transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }
        
        // Try to extract signature response from result
        guard let signatureResponse = try? anycodable.get(PolkadotSignatureResponse.self) else {
            return nil
        }
        
        // Try to extract request params - this is now available!
        guard let rpcParams = rpcParams,
              let requestParams = try? rpcParams.get(PolkadotRequestParams.self) else {
            return nil
        }
        
        // Calculate the hash using both signature response and request params
        guard let calculatedHash = calculatePolkadotHash(signatureResponse: signatureResponse, requestParams: requestParams) else {
            return nil
        }
        
        return [calculatedHash]
    }
    
    // MARK: - Hash Calculation
    
    /// Calculates Polkadot transaction hash from signature response and request params
    private func calculatePolkadotHash(signatureResponse: PolkadotSignatureResponse, requestParams: PolkadotRequestParams) -> String? {
        do {
            let address = requestParams.address ?? requestParams.transactionPayload.address ?? ""
            let publicKey = try ss58AddressToPublicKey(address)
            let signedExtrinsic = try addSignatureToExtrinsic(
                publicKey: publicKey,
                signature: signatureResponse.signature,
                payload: requestParams.transactionPayload
            )
            return deriveExtrinsicHash(signedExtrinsic)
        } catch {
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// Derives the extrinsic hash using Blake2b-256
    private func deriveExtrinsicHash(_ signed: Data) -> String {
        do {
            // Use Blake2b with 256-bit output (32 bytes)
            let hashData = try BLAKE2b.hash(data: signed, digestLength: 32)
            return hashData.map { String(format: "%02x", $0) }.joined()
        } catch {
            return ""
        }
    }
    
    /// Converts SS58 address to public key
    private func ss58AddressToPublicKey(_ ss58Address: String) throws -> Data {
        let decoded = Base58.decode(ss58Address)
        
        guard decoded.count >= 33 else {
            throw PolkadotTVFError.invalidAddress
        }
        
        // Extract public key (skip first byte which is prefix, take next 32 bytes)
        return decoded.subdata(in: 1..<33)
    }
    
    /// SCALE-encoding of the unsigned payload along with the signature
    private func addSignatureToExtrinsic(
        publicKey: Data,
        signature: String,
        payload: PolkadotTransactionPayload
    ) throws -> Data {
        let method = try hexStringToData(payload.method)
        let signatureData = try hexStringToData(signature)
        
        let signedFlag: UInt8 = 0x80 // For signed extrinsics
        let version = payload.version ?? 4
        // Extrinsic version = signed flag + version
        let extrinsicVersion = signedFlag | UInt8(version) // 0x80 + 0x04 = 0x84
        
        // Detect signature type by evaluating the address
        let address = payload.address ?? ""
        let signatureType = guessSignatureTypeFromAddress(address)
        
        // Era - handle era properly for Polkadot
        let eraBytes = try processEra(payload.era)
        
        // Nonce - use raw hex value, not compact encoded
        let nonceValue = try parseHex(payload.nonce ?? "0")
        let nonceBytes = Data([UInt8(nonceValue & 0xFF)])
        
        // Tip - use compact encoding
        let tipValue = try parseHexBigInt(payload.tip ?? "0")
        let tipBytes = try compactEncode(tipValue)
        
        // Handle method - only insert 00 byte if not already present
        let finalMethod = try processMethod(method)
        
        // Build the extrinsic body
        var extrinsicBody = Data()
        extrinsicBody.append(0x00) // MultiAddress::Id
        extrinsicBody.append(publicKey)
        extrinsicBody.append(UInt8(signatureType))
        extrinsicBody.append(signatureData)
        extrinsicBody.append(eraBytes)
        extrinsicBody.append(nonceBytes)
        extrinsicBody.append(tipBytes)
        extrinsicBody.append(0x00) // Additional 00 byte before method
        extrinsicBody.append(finalMethod)
        
        // Add length prefix and version
        let lengthPrefix = try compactEncodeInt(extrinsicBody.count + 1) // +1 for version byte
        
        var result = Data()
        result.append(lengthPrefix)
        result.append(extrinsicVersion)
        result.append(extrinsicBody)
        
        return result
    }
    
    private func guessSignatureTypeFromAddress(_ address: String) -> Int {
        do {
            if address.starts(with: "0x") {
                return 0x02 // ecdsa
            }
            
            let decoded = Base58.decode(address)
            guard !decoded.isEmpty else { return 0x01 }
            
            let prefix = Int(decoded[0])
            
            // https://github.com/paritytech/ss58-registry/blob/main/ss58-registry.json
            switch prefix {
            case 42:
                return 0x00 // Ed25519
            case 60:
                return 0x02 // Secp256k1
            default:
                return 0x01 // Sr25519 for most chains, Polkadot, Kusama, etc
            }
        } catch {
            return 0x01 // fallback
        }
    }
    
    private func processEra(_ era: String?) throws -> Data {
        let eraValue = normalizeHex(era ?? "")
        if eraValue.isEmpty || eraValue == "00" {
            return Data([0x00]) // Immortal
        } else {
            // For mortal era, just use the hex bytes as-is
            return try hexStringToData(eraValue)
        }
    }
    
    private func processMethod(_ method: Data) throws -> Data {
        // Handle method - only insert 00 byte if not already present
        if method.count >= 3 &&
           method[0] == 0x05 &&
           method[1] == 0x03 &&
           method[2] != 0x00 {
            // Method needs 00 byte inserted after first two bytes (05 03 -> 05 03 00)
            var finalMethod = Data()
            finalMethod.append(method[0]) // 05
            finalMethod.append(method[1]) // 03
            finalMethod.append(0x00)      // 00
            finalMethod.append(method.subdata(in: 2..<method.count)) // rest
            return finalMethod
        } else {
            // Method already has correct format or different structure
            return method
        }
    }
    
    private func normalizeHex(_ input: String) -> String {
        return input.hasPrefix("0x") ? String(input.dropFirst(2)) : input
    }
    
    private func parseHex(_ input: String) throws -> Int {
        let raw = normalizeHex(input)
        guard let value = Int(raw, radix: 16) else {
            throw PolkadotTVFError.invalidHexString
        }
        return value
    }
    
    private func parseHexBigInt(_ input: String) throws -> UInt64 {
        let raw = normalizeHex(input)
        guard let value = UInt64(raw, radix: 16) else {
            throw PolkadotTVFError.invalidHexString
        }
        return value
    }
    
    private func hexStringToData(_ hex: String) throws -> Data {
        let normalized = normalizeHex(hex)
        var data = Data()
        var index = normalized.startIndex
        
        while index < normalized.endIndex {
            let nextIndex = normalized.index(index, offsetBy: 2, limitedBy: normalized.endIndex) ?? normalized.endIndex
            let byteString = String(normalized[index..<nextIndex])
            
            guard let byte = UInt8(byteString, radix: 16) else {
                throw PolkadotTVFError.invalidHexString
            }
            
            data.append(byte)
            index = nextIndex
        }
        
        return data
    }
    
    private func compactEncodeInt(_ value: Int) throws -> Data {
        return try compactEncode(UInt64(value))
    }
    
    private func compactEncode(_ value: UInt64) throws -> Data {
        switch value {
        case 0..<(1 << 6):
            return Data([UInt8(value << 2)])
            
        case 0..<(1 << 14):
            let encoded = (value << 2) | 0x01
            return Data([
                UInt8(encoded & 0xFF),
                UInt8((encoded >> 8) & 0xFF)
            ])
            
        case 0..<(1 << 30):
            let encoded = (value << 2) | 0x02
            return Data([
                UInt8(encoded & 0xFF),
                UInt8((encoded >> 8) & 0xFF),
                UInt8((encoded >> 16) & 0xFF),
                UInt8((encoded >> 24) & 0xFF)
            ])
            
        default:
            // big-integer mode
            let bytes = bigIntToLEBytes(value)
            guard bytes.count <= 67 else {
                throw PolkadotTVFError.compactEncodingTooLarge
            }
            
            var result = Data()
            result.append(UInt8(((bytes.count - 4) << 2) | 0x03))
            result.append(contentsOf: bytes)
            return result
        }
    }
    
    private func bigIntToLEBytes(_ value: UInt64) -> Data {
        var bytes = Data()
        var current = value
        
        while current > 0 {
            bytes.append(UInt8(current & 0xFF))
            current >>= 8
        }
        
        return bytes
    }
}

// MARK: - Error Types

enum PolkadotTVFError: Error {
    case invalidAddress
    case invalidHexString
    case compactEncodingTooLarge
}
