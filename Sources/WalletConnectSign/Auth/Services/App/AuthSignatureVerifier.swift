import Foundation

public class AuthSignatureVerifier {
    
    enum Errors: Error, LocalizedError {
        case unsupportedSignatureType(signatureType: String, supportedTypes: [String], recommendedVerifier: String)
        
        var errorDescription: String? {
            switch self {
            case .unsupportedSignatureType(let signatureType, let supportedTypes, let recommendedVerifier):
                return "Unsupported signature type '\(signatureType)'. Supported types: \(supportedTypes.joined(separator: ", ")). \(recommendedVerifier)."
            }
        }
    }
    
    private let messageFormatter: SignWithXFormatting
    private let signatureVerifier: MessageVerifier
    private let logger: ConsoleLogging

    init(
        messageFormatter: SignWithXFormatting,
        signatureVerifier: MessageVerifier,
        logger: ConsoleLogging
    ) {
        self.messageFormatter = messageFormatter
        self.signatureVerifier = signatureVerifier
        self.logger = logger
    }

    public func recoverAndVerifySignature(authObject: AuthObject) async throws {
        // Check if signature type is supported (EVM only)
        guard authObject.s.t.namespace == "eip155" else {
            throw Errors.unsupportedSignatureType(
                signatureType: "\(authObject.s.t.namespace).\(authObject.s.t.algorithm)",
                supportedTypes: ["eip155.eip191", "eip155.eip1271", "eip155.eip6492"],
                recommendedVerifier: getRecommendedVerifier(for: authObject.s.t)
            )
        }
        
        guard
            let account = try? DIDPKH(did: authObject.p.iss).account,
            let message = try? messageFormatter.formatMessage(from: authObject.p, includeRecapInTheStatement: false)
        else {
            throw AuthError.malformedResponseParams
        }
        do {
            try await signatureVerifier.verify(
                signature: authObject.s,
                message: message,
                account: account
            )
        } catch {
            logger.error("Signature verification failed with: \(error.localizedDescription)")
            throw AuthError.signatureVerificationFailed
        }
    }
    
    private func getRecommendedVerifier(for signatureType: CacaoSignatureType) -> String {
        switch signatureType.namespace {
        case "bip122":
            return "Use a Bitcoin signature verifier for ECDSA and BIP-322 signatures"
        case "solana":
            return "Use a Solana signature verifier for Ed25519 signatures"
        default:
            return "Use a signature verifier specific to the \(signatureType.namespace) namespace"
        }
    }
} 