import Foundation

public enum CacaoSignatureType: Codable, Equatable {
    case eip155(Eip155)
    case bip122(Bip122)
    case solana(Solana)
    
    public enum Eip155: String, Codable {
        case eip191
        case eip1271
        case eip6492
    }
    
    public enum Bip122: String, Codable {
        case ecdsa
        case bip322Simple = "bip322-simple"
    }
    
    public enum Solana: String, Codable {
        case ed25519
    }
    
    /// Returns the blockchain namespace this signature type belongs to
    public var namespace: String {
        switch self {
        case .eip155:
            return "eip155"
        case .bip122:
            return "bip122"
        case .solana:
            return "solana"
        }
    }
    
    /// Returns the signature algorithm
    public var algorithm: String {
        switch self {
        case .eip155(let type):
            return type.rawValue
        case .bip122(let type):
            return type.rawValue
        case .solana(let type):
            return type.rawValue
        }
    }
    
    /// Creates signature type from namespace and algorithm
    fileprivate static func from(namespace: String, algorithm: String) -> CacaoSignatureType? {
        switch namespace {
        case "eip155":
            guard let eip155Type = Eip155(rawValue: algorithm) else { return nil }
            return .eip155(eip155Type)
        case "bip122":
            guard let bip122Type = Bip122(rawValue: algorithm) else { return nil }
            return .bip122(bip122Type)
        case "solana":
            guard let solanaType = Solana(rawValue: algorithm) else { return nil }
            return .solana(solanaType)
        default:
            return nil
        }
    }
}

// MARK: - Codable Implementation
extension CacaoSignatureType {
    
    /// All supported namespaces
    private static var supportedNamespaces: [String] {
        return ["eip155", "bip122", "solana"]
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        
        // Try to find which namespace supports this algorithm
        for namespace in Self.supportedNamespaces {
            if let signatureType = CacaoSignatureType.from(namespace: namespace, algorithm: stringValue) {
                self = signatureType
                return
            }
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown signature type: \(stringValue)")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let stringValue = algorithm
        try container.encode(stringValue)
    }
}

public struct CacaoSignature: Codable, Equatable {
    public let t: CacaoSignatureType
    public let s: String
    public let m: String?

    public init(t: CacaoSignatureType, s: String, m: String? = nil) {
        self.t = t
        self.s = s
        self.m = m
    }
}
