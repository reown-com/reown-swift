import Foundation
import WalletConnectSign
import WalletConnectSigner
import WalletConnectUtils

final class AuthSignatureVerifier {
    private let messageFormatter: SignWithXFormatting
    private let signatureVerifier: MessageVerifier
    private let logger: ConsoleLogging

    init(
        messageFormatter: SignWithXFormatting = SIWEFromCacaoPayloadFormatter(),
        signatureVerifier: MessageVerifier = MessageVerifierFactory(crypto: DefaultCryptoProvider()).create(projectId: InputConfig.projectId),
        logger: ConsoleLogging = ConsoleLogger(prefix: "DAppAuthVerifier", loggingLevel: .warn)
    ) {
        self.messageFormatter = messageFormatter
        self.signatureVerifier = signatureVerifier
        self.logger = logger
    }

    func recoverAndVerifySignature(authObject: AuthObject) async throws {
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
