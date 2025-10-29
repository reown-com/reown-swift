import Foundation
import ReownWalletKit
import YttriumUtilsWrapper
// MARK: - Sui Request Parameter Models

struct SuiSignPersonalMessageParams: Codable {
    let address: String
    let message: String
}

struct SuiSignTransactionParams: Codable {
    let address: String
    let transaction: String // base64 encoded transaction
}

// MARK: - SuiSigner

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
        let bundleId: String = Bundle.main.bundleIdentifier ?? ""
        let pulseMetadata = YttriumUtils.PulseMetadata(
            url: nil,
            bundleId: bundleId,
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
        let params = try parsePersonalMessageParams(from: request)
        
        guard let messageData = params.message.data(using: .utf8) else {
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
        
        let params = try parseTransactionParams(from: request)
        
        guard let transactionData = Data(base64Encoded: params.transaction) else {
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
        
        let params = try parseTransactionParams(from: request)
        
        guard let transactionData = Data(base64Encoded: params.transaction) else {
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
    
    // MARK: - Parameter Parsing Methods
    
    private func parsePersonalMessageParams(from request: Request) throws -> SuiSignPersonalMessageParams {
        do {
            return try request.params.get(SuiSignPersonalMessageParams.self)
        } catch {
            throw Errors.invalidRequestParameters
        }
    }
    
    private func parseTransactionParams(from request: Request) throws -> SuiSignTransactionParams {
        do {
            return try request.params.get(SuiSignTransactionParams.self)
        } catch {
            throw Errors.invalidRequestParameters
        }
    }
} 
