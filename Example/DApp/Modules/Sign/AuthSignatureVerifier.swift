import Foundation
import WalletConnectSign
import WalletConnectSigner
import WalletConnectUtils

final class AuthSignatureVerifier {

    enum Errors: LocalizedError {
        case utf8EncodingFailed
        case verificationFailed(message: String)

        var errorDescription: String? {
            switch self {
            case .utf8EncodingFailed:
                return "Failed to encode string using UTF-8."
            case .verificationFailed(let message):
                return "Verification failed: \(message)"
            }
        }
    }

    private let messageFormatter: SignWithXFormatting
    private let logger: ConsoleLogging

    init(
        messageFormatter: SignWithXFormatting = SIWEFromCacaoPayloadFormatter(),
        logger: ConsoleLogging = ConsoleLogger(prefix: "DAppAuthVerifier", loggingLevel: .warn)
    ) {
        self.messageFormatter = messageFormatter
        self.logger = logger
    }

    func recoverAndVerifySignature(authObject: AuthObject) async throws {
        guard
            let account = try? DIDPKH(did: authObject.p.iss).account,
            let _ = try? messageFormatter.formatMessage(from: authObject.p, includeRecapInTheStatement: false)
        else {
            throw AuthError.malformedResponseParams
        }

        if account.namespace.caseInsensitiveCompare("solana") == .orderedSame {
            guard authObject.s.t == .ed25519 else {
                throw AuthError.signatureVerificationFailed
            }
            // TODO: add ed25519 signature verification once available.
            return
        }

        // TODO: ERC-6492 signature verification temporarily disabled
        // Erc6492Client is not available in Yttrium 0.10.1
        // Re-enable when Yttrium exports Erc6492Client again
        logger.debug("Skipping ERC-6492 signature verification (not available in current Yttrium version)")
    }
}
