import Foundation
import ReownWalletKit
import YttriumUtilsWrapper
import CryptoKit

// MARK: - TON Request Parameter Models

struct TonSignDataParams: Codable {
    let from: String
    let text: String
    let type: String?
}

// MARK: - TonSigner

final class TonSigner {
    enum Errors: LocalizedError {
        case tonAccountNotFound
        case invalidRequestParameters
        case invalidPrivateKeyFormat
        case signingFailed(String)

        var errorDescription: String? {
            switch self {
            case .tonAccountNotFound:
                return "TON account not found in storage"
            case .invalidRequestParameters:
                return "Invalid request parameters for TON method"
            case .invalidPrivateKeyFormat:
                return "Invalid TON private key format (expect base64 32-byte seed)"
            case .signingFailed(let message):
                return "TON signing failed: \(message)"
            }
        }
    }

    private let tonAccountStorage = TonAccountStorage()

    func sign(request: Request) async throws -> AnyCodable {
        guard let privateKeyBase64 = tonAccountStorage.getPrivateKey() else {
            throw Errors.tonAccountNotFound
        }

        switch request.method {
        case "ton_signData":
            return try await signData(request: request, privateKeyBase64: privateKeyBase64)
        case "ton_sendMessage":
            throw Signer.Errors.notImplemented
        default:
            throw Signer.Errors.notImplemented
        }
    }

    private func signData(request: Request, privateKeyBase64: String) async throws -> AnyCodable {
        let params = try parseSignDataParams(from: request)

        // Optional: verify the requested address matches our TON address for this chain
        if let ourAddress = tonAccountStorage.getAddress(for: request.chainId),
           params.from.lowercased() != ourAddress.lowercased() {
            throw Signer.Errors.accountForRequestNotFound
        }

        guard let skData = Data(base64Encoded: privateKeyBase64), skData.count == 32 else {
            throw Errors.invalidPrivateKeyFormat
        }

        guard let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: skData) else {
            throw Errors.invalidPrivateKeyFormat
        }
        let pubData = privateKey.publicKey.rawRepresentation
        let pkHex = pubData.map { String(format: "%02x", $0) }.joined()

        do {
            let cfg = TonClientConfig(networkId: request.chainId.absoluteString)
            let client = try TonClient(cfg: cfg)
            let signature = try client.signData(text: params.text, keypair: Keypair(sk: privateKeyBase64, pk: pkHex))
            let response = ["signature": signature]
            return AnyCodable(response)
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }

    // MARK: - Parameter Parsing
    private func parseSignDataParams(from request: Request) throws -> TonSignDataParams {
        guard let arr = try? request.params.get([TonSignDataParams].self), let first = arr.first else {
            throw Errors.invalidRequestParameters
        }
        return first
    }
}


