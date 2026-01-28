import Foundation
import ReownWalletKit
import YttriumUtilsWrapper

// MARK: - Tron Request Parameter Models

struct TronSignMessageParams: Codable {
    let address: String
    let message: String
}

struct TronSignTransactionParams: Codable {
    let address: String
    let transaction: TronTransactionData
}

struct TronTransactionData: Codable {
    let raw_data_hex: String?
    let raw_data: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case raw_data_hex
        case raw_data
    }
}

// MARK: - TronSigner

final class TronSigner {
    enum Errors: LocalizedError {
        case tronAccountNotFound
        case invalidRequestParameters
        case invalidPrivateKeyFormat
        case signingFailed(String)
        case addressMismatch
        case missingRawDataHex

        var errorDescription: String? {
            switch self {
            case .tronAccountNotFound:
                return "Tron account not found in storage"
            case .invalidRequestParameters:
                return "Invalid request parameters for Tron method"
            case .invalidPrivateKeyFormat:
                return "Invalid Tron private key format (expected 64 hex chars)"
            case .signingFailed(let message):
                return "Tron signing failed: \(message)"
            case .addressMismatch:
                return "Request address does not match stored Tron account"
            case .missingRawDataHex:
                return "Transaction missing raw_data_hex field"
            }
        }
    }

    private let tronAccountStorage = TronAccountStorage()

    func sign(request: Request) async throws -> AnyCodable {
        guard let privateKeyHex = tronAccountStorage.getPrivateKey(),
              let publicKeyHex = tronAccountStorage.getPublicKey() else {
            throw Errors.tronAccountNotFound
        }

        switch request.method {
        case "tron_signMessage":
            return try await signMessage(request: request, privateKeyHex: privateKeyHex, publicKeyHex: publicKeyHex)
        case "tron_signTransaction":
            return try await signTransaction(request: request, privateKeyHex: privateKeyHex, publicKeyHex: publicKeyHex)
        default:
            throw Signer.Errors.notImplemented
        }
    }

    // MARK: - tron_signMessage (TIP-191)

    private func signMessage(request: Request, privateKeyHex: String, publicKeyHex: String) async throws -> AnyCodable {
        let params = try parseSignMessageParams(from: request)

        // Verify address matches our stored account
        if let ourAddress = tronAccountStorage.getAddress(for: request.chainId),
           params.address != ourAddress {
            throw Errors.addressMismatch
        }

        do {
            let keypair = TronKeypair(sk: privateKeyHex, pk: publicKeyHex)
            let signature = try tronSignMessage(message: params.message, keypair: keypair)
            return AnyCodable(any: ["signature": signature])
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }

    // MARK: - tron_signTransaction

    private func signTransaction(request: Request, privateKeyHex: String, publicKeyHex: String) async throws -> AnyCodable {
        let rawDataHex = try parseTransactionRawDataHex(from: request)

        do {
            let keypair = TronKeypair(sk: privateKeyHex, pk: publicKeyHex)
            let signedTx = try tronSignTransaction(rawDataHex: rawDataHex, keypair: keypair)

            // Return format compatible with TronSignTransactionResult
            return AnyCodable(any: [
                "txID": signedTx.txId,
                "signature": signedTx.signature,
                "raw_data_hex": signedTx.rawDataHex
            ])
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }

    // MARK: - Parameter Parsing

    private func parseSignMessageParams(from request: Request) throws -> TronSignMessageParams {
        // Try direct object first
        if let params = try? request.params.get(TronSignMessageParams.self) {
            return params
        }
        // Try array format
        if let arr = try? request.params.get([TronSignMessageParams].self), let first = arr.first {
            return first
        }
        throw Errors.invalidRequestParameters
    }

    private func parseTransactionRawDataHex(from request: Request) throws -> String {
        // Try to get raw_data_hex from various formats

        // Format 1: { address: "", transaction: { raw_data_hex: "" } } (v1 format)
        if let dict = try? request.params.get([String: AnyCodable].self),
           let transaction = dict["transaction"]?.value as? [String: Any],
           let rawDataHex = transaction["raw_data_hex"] as? String {
            return rawDataHex
        }

        // Format 2: Direct object with raw_data_hex at root
        if let dict = try? request.params.get([String: AnyCodable].self),
           let rawDataHex = dict["raw_data_hex"]?.value as? String {
            return rawDataHex
        }

        // Format 3: Array format [{ address: "", transaction: { raw_data_hex: "" } }]
        if let arr = try? request.params.get([AnyCodable].self),
           let first = arr.first?.value as? [String: Any],
           let transaction = first["transaction"] as? [String: Any],
           let rawDataHex = transaction["raw_data_hex"] as? String {
            return rawDataHex
        }

        // Format 4: Array with direct raw_data_hex
        if let arr = try? request.params.get([AnyCodable].self),
           let first = arr.first?.value as? [String: Any],
           let rawDataHex = first["raw_data_hex"] as? String {
            return rawDataHex
        }

        throw Errors.missingRawDataHex
    }
}
