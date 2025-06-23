import Foundation
import ReownWalletKit
import WalletConnectSign

// MARK: - Stacks Request Parameter Models

struct StacksStxTransferParams: Codable {
    let sender: String // The stacks address of sender
    let recipient: String // The STX address of the recipient
    let amount: String // Amount of STX tokens to transfer in microstacks
    let memo: String? // Optional memo string to be included with the transfer transaction
}

struct StacksSignMessageParams: Codable {
    let address: String // The stacks address of sender
    let message: String // Utf-8 string representing the message to be signed by the wallet
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
        case senderMismatch
        
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
            case .senderMismatch:
                return "Sender address does not match the wallet address"
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
        
        // Verify sender matches our wallet address
        if let ourAddress = try stacksAccountStorage.getAddress(),
           params.sender.lowercased() != ourAddress.lowercased() {
            throw Errors.senderMismatch
        }
        
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
                network: StacksAccountStorage.chainId.absoluteString,
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
        
        // Verify address matches our wallet address
        if let ourAddress = try stacksAccountStorage.getAddress(),
           params.address.lowercased() != ourAddress.lowercased() {
            throw Errors.senderMismatch
        }
        
        do {
            let signature = try stacksSignMessage(
                wallet: wallet,
                message: params.message
            )
            
            let response = [
                "signature": signature
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
