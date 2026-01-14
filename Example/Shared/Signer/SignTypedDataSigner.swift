import Foundation
import YttriumUtilsWrapper

/// Generic EIP-712 typed data signer using EvmSigningClient from YttriumUtilsWrapper
final class SignTypedDataSigner {
    
    private static let evmSigningClient: EvmSigningClient = {
        let metadata = PulseMetadata(
            url: nil,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            sdkVersion: "reown-swift-mobile-1.0",
            sdkPlatform: "mobile"
        )
        return EvmSigningClient(projectId: InputConfig.projectId, pulseMetadata: metadata)
    }()
    
    private let privateKey: String
    
    init(privateKey: String) {
        self.privateKey = privateKey
    }
    
    /// Sign EIP-712 typed data from params
    /// Handles both formats:
    /// - Direct typed data: {"types": ..., "message": ...}
    /// - Array format: [address, typedData]
    func signTypedDataFromParams(_ params: String) async throws -> String {
        let typedDataJson = try extractTypedData(from: params)
        return try await Self.evmSigningClient.signTypedData(
            jsonData: typedDataJson,
            signer: privateKey
        )
    }
    
    private func extractTypedData(from params: String) throws -> String {
        guard let data = params.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            throw SignTypedDataError.invalidParams
        }
        
        // If it's already the typed data object
        if json is [String: Any] {
            return params
        }
        
        // If it's [address, typedData] array
        if let array = json as? [Any], array.count >= 2 {
            let typedData = array[1]
            
            // If typedData is already a String (JSON string), return it directly
            if let typedDataString = typedData as? String {
                return typedDataString
            }
            
            // If typedData is a dictionary, serialize it
            if typedData is [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: typedData, options: .sortedKeys)
                return String(data: jsonData, encoding: .utf8) ?? ""
            }
        }
        
        throw SignTypedDataError.invalidParams
    }
    
    enum SignTypedDataError: Error, LocalizedError {
        case invalidParams
        
        var errorDescription: String? {
            "Invalid typed data parameters"
        }
    }
}
