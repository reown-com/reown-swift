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

// ton_signMessage is not part of the target API (use ton_signData instead)

struct TonSendTxMessageParams: Codable {
    let address: String
    let amount: String
    let stateInit: String?
    let payload: String?

    enum CodingKeys: String, CodingKey {
        case address
        case amount
        case stateInit = "state_init"
        case payload
    }
}

struct TonSendMessageParams: Codable {
    let network: String?
    let from: String
    let validUntil: UInt32
    let messages: [TonSendTxMessageParams]

    enum CodingKeys: String, CodingKey {
        case network
        case from
        case validUntil = "valid_until"
        case messages
    }
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
            return try await sendMessage(request: request, privateKeyBase64: privateKeyBase64)
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
            let bundleId: String = Bundle.main.bundleIdentifier ?? ""
            let pulseMetadata = YttriumUtils.PulseMetadata(
                url: nil,
                bundleId: bundleId,
                sdkVersion: "reown-swift-\(EnvironmentInfo.sdkName)",
                sdkPlatform: "mobile"
            )
            let clientNetworkId = normalizeTonNetworkId(from: request.chainId.absoluteString)
            let cfg = TonClientConfig(networkId: clientNetworkId)
            let client = TonClient(cfg: cfg, projectId: InputConfig.projectId, pulseMetadata: pulseMetadata)
            let signature = try client.signData(text: params.text, keypair: Keypair(sk: privateKeyBase64, pk: pkHex))
            let response = ["signature": signature]
            return AnyCodable(response)
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }

    private func sendMessage(request: Request, privateKeyBase64: String) async throws -> AnyCodable {
        let params = try parseSendMessageParams(from: request)

        // Normalize WC chain id to RPC network id (e.g., ton:-239 -> ton:mainnet)
        let clientNetworkId = normalizeTonNetworkId(from: request.chainId.absoluteString)
        // If the request provided a network string, ensure it matches the normalized one
        if let reqNetwork = params.network, reqNetwork != clientNetworkId {
            throw Errors.signingFailed("Network mismatch: client=\(clientNetworkId) request=\(reqNetwork)")
        }

        guard let skData = Data(base64Encoded: privateKeyBase64), skData.count == 32 else {
            throw Errors.invalidPrivateKeyFormat
        }
        guard let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: skData) else {
            throw Errors.invalidPrivateKeyFormat
        }
        let pubData = privateKey.publicKey.rawRepresentation
        let pkHex = pubData.map { String(format: "%02x", $0) }.joined()

        let bundleId: String = Bundle.main.bundleIdentifier ?? ""
        let pulseMetadata = YttriumUtils.PulseMetadata(
            url: nil,
            bundleId: bundleId,
            sdkVersion: "reown-swift-\(EnvironmentInfo.sdkName)",
            sdkPlatform: "mobile"
        )
        let cfg = TonClientConfig(networkId: clientNetworkId)
        let client = TonClient(cfg: cfg, projectId: InputConfig.projectId, pulseMetadata: pulseMetadata)

        // Map params to wrapper SendTxMessage
        let messages = params.messages.map { m in
            SendTxMessage(address: m.address, amount: m.amount, stateInit: m.stateInit, payload: m.payload)
        }

        let keypair = Keypair(sk: privateKeyBase64, pk: pkHex)
        let boc = try await client.sendMessage(
            network: clientNetworkId,
            from: params.from,
            keypair: keypair,
            validUntil: params.validUntil,
            messages: messages
        )

        return AnyCodable(["boc": boc])
    }

    // MARK: - Parameter Parsing
    private func parseSignDataParams(from request: Request) throws -> TonSignDataParams {
        guard let arr = try? request.params.get([TonSignDataParams].self), let first = arr.first else {
            throw Errors.invalidRequestParameters
        }
        return first
    }

    private func normalizeTonNetworkId(from caip2: String) -> String {
        // WalletConnect sessions use ton:-239/ton:-3; Rust RPC expects ton:mainnet/ton:testnet
        if caip2 == "ton:-239" { return "ton:mainnet" }
        if caip2 == "ton:-3" { return "ton:testnet" }
        return caip2
    }

    private func parseSendMessageParams(from request: Request) throws -> TonSendMessageParams {
        if let params = try? request.params.get(TonSendMessageParams.self) {
            return params
        }
        // Fallback array form
        if let arr = try? request.params.get([TonSendMessageParams].self), let first = arr.first {
            return first
        }
        throw Errors.invalidRequestParameters
    }
}


