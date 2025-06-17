import Foundation
import ReownWalletKit
import WalletConnectSign

// MARK: - Stacks Request Parameter Models

struct StacksStxTransferParams: Codable {
    let pubkey: String
    let recipient: String
    let amount: String
    let memo: String?
}

struct StacksSignMessageParams: Codable {
    let pubkey: String
    let message: String
}

// MARK: - StacksSigner

final class StacksSigner {
    enum Errors: LocalizedError {
        case stacksAccountNotFound
        case invalidRequestParameters
        case invalidTransactionData
        case invalidMessageData
        case signingFailed(String)
        
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
            }
        }
    }
    
    private let stacksAccountStorage = StacksAccountStorage()
    
    func sign(request: Request) async throws -> AnyCodable {
        guard let wallet = stacksAccountStorage.getWallet() else {
            throw Errors.stacksAccountNotFound
        }
        
        switch request.method {
        case "stacks_stxTransfer":
            return try await handleStxTransfer(request: request, wallet: wallet)
        case "stacks_signMessage":
            return try await handleSignMessage(request: request, wallet: wallet)
        default:
            throw Signer.Errors.notImplemented
        }
    }
    
    private func handleStxTransfer(request: Request, wallet: String) async throws -> AnyCodable {
        let params = try parseStxTransferParams(from: request)
        
        do {
            let result = try stacksSignAndSendTransaction(
                wallet: wallet,
                recipient: params.recipient,
                amount: params.amount,
                memo: params.memo
            )
            
            let response = [
                "txId": result.txId,
                "txRaw": result.txRaw
            ]
            return AnyCodable(response)
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }
    
    private func handleSignMessage(request: Request, wallet: String) async throws -> AnyCodable {
        let params = try parseSignMessageParams(from: request)
        
        do {
            let result = try stacksSignMessage(
                wallet: wallet,
                message: params.message
            )
            
            let response = [
                "signature": result.signature,
                "publicKey": result.publicKey
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
