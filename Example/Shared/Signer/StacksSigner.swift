import Foundation
import ReownWalletKit

final class StacksSigner: Signer {
    static var address: String {
        do {
            return try StacksAccountStorage().getAddress() ?? ""
        } catch {
            return ""
        }
    }
    
    func sign(_ request: Request) async throws -> Response {
        switch request.method {
        case "stacks_stxTransfer":
            return try await handleStxTransfer(request)
        case "stacks_signMessage":
            return try await handleSignMessage(request)
        default:
            throw SignerError.unsupportedMethod
        }
    }
    
    private func handleStxTransfer(_ request: Request) async throws -> Response {
        guard let params = request.params as? [String: Any],
              let pubkey = params["pubkey"] as? String,
              let recipient = params["recipient"] as? String,
              let amount = params["amount"] as? String else {
            throw SignerError.invalidParams
        }
        
        // Get wallet from storage
        let stacksStorage = StacksAccountStorage()
        guard let wallet = stacksStorage.getWallet() else {
            throw SignerError.invalidWallet
        }
        
        // Sign and send transaction using stacks FFI
        let result = try stacksSignAndSendTransaction(
            wallet: wallet,
            recipient: recipient,
            amount: amount,
            memo: params["memo"] as? String
        )
        
        return Response(
            id: request.id,
            result: [
                "txId": result.txId,
                "txRaw": result.txRaw
            ]
        )
    }
    
    private func handleSignMessage(_ request: Request) async throws -> Response {
        guard let params = request.params as? [String: Any],
              let pubkey = params["pubkey"] as? String,
              let message = params["message"] as? String else {
            throw SignerError.invalidParams
        }
        
        // Get wallet from storage
        let stacksStorage = StacksAccountStorage()
        guard let wallet = stacksStorage.getWallet() else {
            throw SignerError.invalidWallet
        }
        
        // Sign message using stacks FFI
        let result = try stacksSignMessage(
            wallet: wallet,
            message: message
        )
        
        return Response(
            id: request.id,
            result: [
                "signature": result.signature,
                "publicKey": result.publicKey
            ]
        )
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