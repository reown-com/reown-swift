import Foundation

public class AuthSignatureVerifier {
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
} 