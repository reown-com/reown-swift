import Foundation

public enum CacaoSignatureType: String, Codable {
    case eip191
    case eip1271
    case eip6492
    case ed25519
    case ecdsa
    case bip322Simple = "bip322-simple"
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
