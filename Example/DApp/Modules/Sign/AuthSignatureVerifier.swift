import Foundation
import WalletConnectSign
import WalletConnectSigner
import WalletConnectUtils
import Yttrium

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
    private let crypto: CryptoProvider
    private let projectId: String
    private let logger: ConsoleLogging

    init(
        messageFormatter: SignWithXFormatting = SIWEFromCacaoPayloadFormatter(),
        crypto: CryptoProvider = DefaultCryptoProvider(),
        projectId: String = InputConfig.projectId,
        logger: ConsoleLogging = ConsoleLogger(prefix: "DAppAuthVerifier", loggingLevel: .warn)
    ) {
        self.messageFormatter = messageFormatter
        self.crypto = crypto
        self.projectId = projectId
        self.logger = logger
    }

    func recoverAndVerifySignature(authObject: AuthObject) async throws {
        guard
            let account = try? DIDPKH(did: authObject.p.iss).account,
            let message = try? messageFormatter.formatMessage(from: authObject.p, includeRecapInTheStatement: false)
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

        do {
            try await verifySignature(
                authObject.s.s,
                message: message,
                address: account.address,
                chainId: account.blockchainIdentifier
            )
        } catch {
            logger.error("Signature verification failed with: \(error.localizedDescription)")
            throw AuthError.signatureVerificationFailed
        }
    }
    
    // MARK: - Private
    
    private func verifySignature(
        _ signatureString: String,
        message: String,
        address: String,
        chainId: String
    ) async throws {
        guard let messageData = message.data(using: .utf8) else {
            throw Errors.utf8EncodingFailed
        }
        let prefixedMessage = messageData.prefixed

        let rpcUrl = "https://rpc.walletconnect.com/v1?chainId=\(chainId)&projectId=\(projectId)"
        let erc6492Client = Erc6492Client(rpcUrl: rpcUrl)
        let messageHash = crypto.keccak256(prefixedMessage)

        let result = try await erc6492Client.verifySignature(
            signature: signatureString,
            address: address,
            messageHash: messageHash.toHexString()
        )

        if result != true {
            throw Errors.verificationFailed(message: "Signature verification failed.")
        }
    }
}

// MARK: - Data Extension for EIP-191 Message Prefixing

private extension Data {
    var prefixed: Data {
        return "\u{19}Ethereum Signed Message:\n\(count)"
            .data(using: .utf8)! + self
    }
}
