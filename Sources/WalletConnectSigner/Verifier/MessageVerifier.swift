import Foundation

public struct MessageVerifier {

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

    private let eip191Verifier: EIP191Verifier
    private let eip1271Verifier: EIP1271Verifier
    private let crypto: CryptoProvider
    private let projectId: String

    init(
        eip191Verifier: EIP191Verifier,
        eip1271Verifier: EIP1271Verifier,
        crypto: CryptoProvider,
        projectId: String
    ) {
        self.eip191Verifier = eip191Verifier
        self.eip1271Verifier = eip1271Verifier
        self.crypto = crypto
        self.projectId = projectId
    }

    public func verify(signature: CacaoSignature,
                       message: String,
                       account: Account
    ) async throws {
        try await self.verify(
            signature: signature,
            message: message,
            address: account.address,
            chainId: account.blockchainIdentifier
        )
    }

    public func verify(signature: CacaoSignature,
                       message: String,
                       address: String,
                       chainId: String
    ) async throws {
        try await verifySignature(signature.s, message: message, address: address, chainId: chainId)
    }

    public func verify(signature: String,
                       message: String,
                       address: String,
                       chainId: String
    ) async throws {
        try await verifySignature(signature, message: message, address: address, chainId: chainId)
    }

    // Private helper method containing the common logic
    private func verifySignature(_ signatureString: String,
                                 message: String,
                                 address: String,
                                 chainId: String
    ) async throws {
        guard let messageData = message.data(using: .utf8) else {
            throw Errors.utf8EncodingFailed
        }

        let signatureData = Data(hex: signatureString)
        let prefixedMessage = messageData.prefixed

        // Try eip191 verification first for better performance
        do {
            try await eip191Verifier.verify(
                signature: signatureData,
                message: prefixedMessage,
                address: address
            )
            return  // If 191 verification succeeds, we’re done
        } catch {
            // If eip191 verification fails, we’ll attempt 6492 verification
        }

        // Fallback to 6492 verification
        // let messageHash = crypto.keccak256(prefixedMessage)
        // erc6492Client.verifySignature(
        //                signature: signatureString,
        //                address: address,
        //                messageHash: messageHash.toHexString()
        //            )
        throw Errors.verificationFailed(message: "Signature verification failed.")
    }
}
