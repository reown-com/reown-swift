import Foundation

/// CAIP-122 Sign with X message formatting protocol
/// Supports multiple blockchain types (Ethereum, Bitcoin, Solana, etc.)
public protocol SignWithXFormatting {
    func formatMessage(from payload: CacaoPayload, includeRecapInTheStatement: Bool) throws -> String
}

public extension SignWithXFormatting {
    func formatMessage(from payload: CacaoPayload) throws -> String {
        return try formatMessage(from: payload, includeRecapInTheStatement: true)
    }
}

/// Legacy protocol name for backward compatibility
/// @deprecated Use SignWithXFormatting instead
public typealias SIWEFromCacaoFormatting = SignWithXFormatting
public typealias SignWithXFormatter = SIWEFromCacaoPayloadFormatter

/// CAIP-122 compliant formatter that supports multiple chain types
/// Previously SIWEFromCacaoPayloadFormatter - now supports Sign with X (CAIP-122)
public struct SIWEFromCacaoPayloadFormatter: SignWithXFormatting {

    /// Errors for unsupported blockchain namespaces
    public enum Errors: Error, LocalizedError {
        case unsupportedNamespace(String)
        
        public var errorDescription: String? {
            switch self {
            case .unsupportedNamespace(let namespace):
                return "Unsupported blockchain namespace: \(namespace). Only eip155, bip122, and solana are supported."
            }
        }
    }

    public init() {}

    public func formatMessage(from payload: CacaoPayload, includeRecapInTheStatement: Bool) throws -> String {
        let iss = try DIDPKH(did: payload.iss)
        let account = iss.account
        let address = account.address
        let chainId = account.reference
        let namespace = account.namespace

        // Determine chain-specific account type for CAIP-122
        let accountType = try getAccountType(for: namespace)
        
        // Directly use the statement from payload, add a newline if it exists
        let statementLine = payload.statement.flatMap { "\n\($0)" } ?? ""

        // Format the message with chain-specific account type (CAIP-122)
        let formattedMessage = """
        \(payload.domain) wants you to sign in with your \(accountType) account:
        \(address)
        \(statementLine)

        URI: \(payload.aud)
        Version: \(payload.version)
        Chain ID: \(chainId)
        Nonce: \(payload.nonce)
        Issued At: \(payload.iat)\(formatExpLine(exp: payload.exp))\(formatNbfLine(nbf: payload.nbf))\(formatRequestIdLine(requestId: payload.requestId))\(formatResourcesSection(resources: payload.resources))
        """
        return formattedMessage
    }

    // CAIP-122: Map chain namespace to account type
    private func getAccountType(for namespace: String) throws -> String {
        switch namespace {
        case "eip155":
            return "Ethereum"
        case "bip122":
            return "Bitcoin"
        case "solana":
            return "Solana"
        default:
            // Only support the three specified chain types
            throw Errors.unsupportedNamespace(namespace)
        }
    }

    // Helper methods for formatting individual parts of the message
    private func formatExpLine(exp: String?) -> String {
        guard let exp = exp else { return "" }
        return "\nExpiration Time: \(exp)"
    }

    private func formatNbfLine(nbf: String?) -> String {
        guard let nbf = nbf else { return "" }
        return "\nNot Before: \(nbf)"
    }

    private func formatRequestIdLine(requestId: String?) -> String {
        guard let requestId = requestId else { return "" }
        return "\nRequest ID: \(requestId)"
    }

    private func formatResourcesSection(resources: [String]?) -> String {
        guard let resources = resources else { return "" }
        let resourcesList = resources.reduce("") { $0 + "\n- \($1)" }
        return resources.isEmpty ? "\nResources:" : "\nResources:" + resourcesList
    }
}
