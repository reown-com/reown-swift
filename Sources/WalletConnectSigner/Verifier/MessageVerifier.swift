import Foundation
import YttriumWrapper

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

    private let crypto: CryptoProvider
    private let projectId: String

    init(
        crypto: CryptoProvider,
        projectId: String
    ) {
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
        let prefixedMessage = messageData.prefixed

        let rpcUrl = "https://rpc.walletconnect.com/v1?chainId=\(chainId)&projectId=\(projectId)"
        let erc6492Client = Erc6492Client(rpcUrl: rpcUrl)
        let messageHash = crypto.keccak256(prefixedMessage)

        do {
            let result = try await erc6492Client.verifySignature(
                signature: signatureString,
                address: address,
                messageHash: messageHash.toHexString()
            )

            if result == true {
                return
            } else {
                throw Errors.verificationFailed(message: "Signature verification failed.")
            }
        } catch {
            throw error
        }
    }
}
