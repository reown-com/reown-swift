import Foundation
import ReownWalletKit
import WalletConnectSign

// MARK: - Stacks Request Parameter Models

struct StacksStxTransferParams: Codable {
    let recipient: String // Stacks c32-encoded address of the recipient
    let amount: String // Amount of STX to transfer (BigInt constructor compatible)
    let memo: String? // Optional memo for the transaction (defaults to an empty string)
}

struct StacksSignMessageParams: Codable {
    let message: String // Arbitrary message for signing
    let messageType: String // Type of message for signing: 'utf8' for basic string or 'structured' for structured data
    let network: String // Network for signing: 'mainnet', 'testnet' (default), 'signet', 'sbtcDevenv' or 'devnet'
    let domain: String? // Domain tuple per SIP-018 (for structured messages only)
}

// MARK: - StacksSigner

final class StacksSigner {
    enum Errors: LocalizedError {
        case stacksAccountNotFound
        case invalidRequestParameters
        case invalidTransactionData
        case invalidMessageData
        case signingFailed(String)
        case invalidAmountFormat
        case invalidNetwork
        
        var errorDescription: String? {
            switch self {
            case .stacksAccountNotFound:
                return "Stacks account not found in storage"
            case .invalidRequestParameters:
                return "Invalid request parameters for Stacks method"
            case .invalidTransactionData:
                return "Invalid transaction data format"
            case .invalidMessageData:
                return "Invalid message data format"
            case .signingFailed(let message):
                return "Stacks signing failed: \(message)"
            case .invalidAmountFormat:
                return "Invalid amount format. Amount must be a valid number."
            case .invalidNetwork:
                return "Invalid network. Must be one of: mainnet, testnet, signet, sbtcDevenv, devnet"
            }
        }
    }
    
    private let stacksAccountStorage = StacksAccountStorage()
    private let stacksClient: StacksClient
    
    init() {
        let pulseMetadata = PulseMetadata(
            url: nil,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            sdkVersion: "reown-swift-\(EnvironmentInfo.sdkName)",
            sdkPlatform: "mobile"
        )
        
        self.stacksClient = StacksClient(projectId: InputConfig.projectId, pulseMetadata: pulseMetadata)
    }
    
    func sign(request: Request) async throws -> AnyCodable {
        guard let wallet = stacksAccountStorage.getWallet() else {
            throw Errors.stacksAccountNotFound
        }
        
        switch request.method {
        case "stx_transferStx":
            return try await handleStxTransfer(request: request, wallet: wallet)
        case "stx_signMessage":
            return try await handleSignMessage(request: request, wallet: wallet)
        default:
            throw Signer.Errors.notImplemented
        }
    }
    
    private func handleStxTransfer(request: Request, wallet: String) async throws -> AnyCodable {
        let params = try parseStxTransferParams(from: request)
        
        // Convert amount string to UInt64
        guard let amount = UInt64(params.amount) else {
            throw Errors.invalidAmountFormat
        }
        
        let transferRequest = TransferStxRequest(
            amount: amount,
            recipient: params.recipient,
            memo: params.memo ?? ""
        )
        
        do {
            let result = try await stacksClient.transferStx(
                wallet: wallet,
                network: "stacks:1",
                request: transferRequest
            )
            
            let response = [
                "txid": result.txid,
                "transaction": result.transaction
            ]
            return AnyCodable(response)
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }
    
    private func handleSignMessage(request: Request, wallet: String) async throws -> AnyCodable {
        let params = try parseSignMessageParams(from: request)
        
        // Validate network
        let validNetworks = ["mainnet", "testnet", "signet", "sbtcDevenv", "devnet"]
        guard validNetworks.contains(params.network) else {
            throw Errors.invalidNetwork
        }
        
        do {
            let signature = try stacksSignMessage(
                wallet: wallet,
                message: params.message
            )
            
            let response = [
                "signature": signature,
                "message": params.message,
                "address": try stacksAccountStorage.getAddress() ?? ""
            ]
            return AnyCodable(response)
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Parameter Parsing Methods
    
    private func parseStxTransferParams(from request: Request) throws -> StacksStxTransferParams {
        do {
            return try request.params.get(StacksStxTransferParams.self)
        } catch {
            throw Errors.invalidRequestParameters
        }
    }
    
    private func parseSignMessageParams(from request: Request) throws -> StacksSignMessageParams {
        do {
            return try request.params.get(StacksSignMessageParams.self)
        } catch {
            throw Errors.invalidRequestParameters
        }
    }
}

// MARK: - SignerError

extension StacksSigner {
    enum SignerError: Error {
        case unsupportedMethod
        case invalidParams
        case invalidWallet
    }
} 
