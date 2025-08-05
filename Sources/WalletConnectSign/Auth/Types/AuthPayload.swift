import Foundation

/// CAIP-222 request params
/// https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-222.md
public struct AuthPayload: Codable, Equatable {
    public let domain: String
    public let aud: String
    public let version: String
    public let nonce: String
    public let chains: [String]
    public let type: String
    public let iat: String
    public let nbf: String?
    public let exp: String?
    public let statement: String?
    public let requestId: String?
    public let resources: [String]?
    public let signatureTypes: [String: [CacaoSignatureType]]?

    internal init(
        domain: String,
        aud: String,
        version: String,
        nonce: String,
        chains: [String],
        type: String,
        iat: String,
        nbf: String? = nil,
        exp: String? = nil,
        statement: String? = nil,
        requestId: String? = nil,
        resources: [String]? = nil,
        signatureTypes: [String: [CacaoSignatureType]]? = nil
    ) {
        self.domain = domain
        self.aud = aud
        self.version = version
        self.nonce = nonce
        self.chains = chains
        self.type = type
        self.iat = iat
        self.nbf = nbf
        self.exp = exp
        self.statement = statement
        self.requestId = requestId
        self.resources = resources
        self.signatureTypes = signatureTypes
    }


    public init(requestParams: AuthRequestParams, iat: String) {
        self.type = "caip122"
        self.chains = requestParams.chains
        self.domain = requestParams.domain
        self.aud = requestParams.uri
        self.version = "1"
        self.nonce = requestParams.nonce
        self.iat = iat
        self.nbf = requestParams.nbf
        self.exp = requestParams.exp
        self.statement = requestParams.statement
        self.requestId = requestParams.requestId
        self.resources = requestParams.resources
        self.signatureTypes = requestParams.signatureTypes
    }
}
