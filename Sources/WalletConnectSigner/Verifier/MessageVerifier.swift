import Foundation
import YttriumWrapper

public struct MessageVerifier {

    enum Errors: LocalizedError {
        case utf8EncodingFailed
        case invalidSignature(message: String)
        case invalidAddress(message: String)
        case invalidMessageHash(message: String)
        case verificationFailed(message: String)
        case custom(message: String)

        var errorDescription: String? {
            switch self {
            case .utf8EncodingFailed:
                return "Failed to encode string using UTF-8."
            case .invalidSignature(let message):
                return "Invalid signature: \(message)"
            case .invalidAddress(let message):
                return "Invalid address: \(message)"
            case .invalidMessageHash(let message):
                return "Invalid message hash: \(message)"
            case .verificationFailed(let message):
                return "Verification failed: \(message)"
            case .custom(let message):
                return message
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
            return  // If 6492 verification succeeds, we’re done
        } catch {
            // If eip191 verification fails, we’ll attempt 6492 verification
        }

        // Fallback to 6492 verification
        print("i was called only once")
        let rpcUrl = "https://rpc.walletconnect.com/v1?chainId=\(chainId)&projectId=\(projectId)"
        let erc6492Client = Erc6492Client(rpcUrl.intoRustString())
        let messageHash = crypto.keccak256(prefixedMessage)

        do {
            let result = try await erc6492Client.verify_signature(
                signatureString.intoRustString(),
                address.intoRustString(),
                messageHash.toHexString().intoRustString()
            )

            if result == true {
                return
            } else {
                throw Errors.verificationFailed(message: "Signature verification failed.")
            }
        } catch let ffiError as Erc6492Error {
            switch ffiError {
            case .InvalidSignature(let x):
                let errorMessage = x.toString()
                throw Errors.invalidSignature(message: errorMessage)
            case .InvalidAddress(let x):
                let errorMessage = x.toString()
                throw Errors.invalidAddress(message: errorMessage)
            case .InvalidMessageHash(let x):
                let errorMessage = x.toString()
                throw Errors.invalidMessageHash(message: errorMessage)
            case .Verification(let x):
                let errorMessage = x.toString()
                throw Errors.verificationFailed(message: errorMessage)
            default:
                let errorMessage = "An unknown error occurred."
                throw Errors.custom(message: errorMessage)
            }
        } catch {
            throw error
        }
    }
}
