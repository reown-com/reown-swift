import Foundation
import ReownWalletKit

final class SuiSigner {
    enum Errors: LocalizedError {
        case suiAccountNotFound
        case invalidRequestParameters
        case invalidTransactionData
        case invalidMessageData
        case signingFailed(String)
        case clientNotInitialized
        
        var errorDescription: String? {
            switch self {
            case .suiAccountNotFound:
                return "Sui account not found in storage"
            case .invalidRequestParameters:
                return "Invalid request parameters for Sui method"
            case .invalidTransactionData:
                return "Invalid transaction data format"
            case .invalidMessageData:
                return "Invalid message data format"
            case .signingFailed(let message):
                return "Sui signing failed: \(message)"
            case .clientNotInitialized:
                return "SuiClient is not initialized"
            }
        }
    }
    
    private let suiAccountStorage = SuiAccountStorage()
    private static var suiClient: SuiClient?
    
    static func initialize(projectId: String) {
        let pulseMetadata = PulseMetadata(
            url: nil,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            sdkVersion: "reown-swift-\(EnvironmentInfo.sdkName)",
            sdkPlatform: "mobile"
        )
        
        suiClient = SuiClient(projectId: projectId, pulseMetadata: pulseMetadata)
    }
    
    func sign(request: Request) async throws -> AnyCodable {
        guard let privateKey = suiAccountStorage.getPrivateKey() else {
            throw Errors.suiAccountNotFound
        }
        
        switch request.method {
        case "sui_signPersonalMessage":
            return try await signPersonalMessage(request: request, keypair: privateKey)
            
        case "sui_signTransaction":
            return try await signTransaction(request: request, keypair: privateKey)
            
        case "sui_signAndExecuteTransaction":
            return try await signAndExecuteTransaction(request: request, keypair: privateKey)
            
        default:
            throw Signer.Errors.notImplemented
        }
    }
    
    private func signPersonalMessage(request: Request, keypair: SuiKeyPair) async throws -> AnyCodable {
        let params = try parseParams(from: request)
        
        guard let message = params["message"] as? String else {
            throw Errors.invalidRequestParameters
        }
        
        guard let messageData = message.data(using: .utf8) else {
            throw Errors.invalidMessageData
        }
        
        do {
            let signature = suiPersonalSign(keypair: keypair, message: messageData)
            let response = ["signature": signature]
            return AnyCodable(response)
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }
    
    private func signTransaction(request: Request, keypair: SuiKeyPair) async throws -> AnyCodable {
        guard let client = Self.suiClient else {
            throw Errors.clientNotInitialized
        }
        
        let params = try parseParams(from: request)
        
        guard let transaction = params["transaction"] as? String else {
            throw Errors.invalidRequestParameters
        }
        
        guard let transactionData = Data(base64Encoded: transaction) else {
            throw Errors.invalidTransactionData
        }
        
        let chainId = request.chainId.absoluteString

        do {
            let result = try await client.signTransaction(
                chainId: chainId,
                keypair: keypair,
                txData: transactionData
            )
            
            let response = [
                "signature": result.signature,
                "transactionBytes": result.txBytes
            ]
            return AnyCodable(response)
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }
    
    private func signAndExecuteTransaction(request: Request, keypair: SuiKeyPair) async throws -> AnyCodable {
        guard let client = Self.suiClient else {
            throw Errors.clientNotInitialized
        }
        
        let params = try parseParams(from: request)
        
        guard let transaction = params["transaction"] as? String else {
            throw Errors.invalidRequestParameters
        }
        
        guard let transactionData = Data(base64Encoded: transaction) else {
            throw Errors.invalidTransactionData
        }
        
        let chainId = request.chainId.absoluteString
        
        do {
            let digest = try await client.signAndExecuteTransaction(
                chainId: chainId,
                keypair: keypair,
                txData: transactionData
            )
            
            let response = ["digest": digest]
            return AnyCodable(response)
        } catch {
            throw Errors.signingFailed(error.localizedDescription)
        }
    }
    
    private func parseParams(from request: Request) throws -> [String: Any] {
        guard let paramsArray = try? request.params.get([AnyCodable].self),
              let firstParam = paramsArray.first?.value as? [String: Any] else {
            throw Errors.invalidRequestParameters
        }
        return firstParam
    }
} 
