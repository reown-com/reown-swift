import Foundation
import YttriumUtilsWrapper

/// Generic EIP-712 typed data signer using EvmSigningClient from YttriumUtilsWrapper
/// Can be used across different contexts that require typed data signing
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
    
    /// Sign EIP-712 typed data
    /// - Parameter typedDataJson: The typed data as a JSON string
    /// - Returns: The signature as a hex string
    func signTypedData(jsonData: String) async throws -> String {
        return try await Self.evmSigningClient.signTypedData(
            jsonData: jsonData,
            signer: privateKey
        )
    }
    
    /// Sign EIP-712 typed data from params array format [address, typedDataJson]
    /// - Parameter params: JSON string containing the params array
    /// - Returns: The signature as a hex string
    func signTypedDataFromParams(_ params: String) async throws -> String {
        // The params is a JSON array: [address, typedDataJson]
        guard let paramsData = params.data(using: .utf8),
              let paramsArray = try? JSONSerialization.jsonObject(with: paramsData) as? [Any],
              paramsArray.count > 1 else {
            throw SignTypedDataError.invalidParams
        }
        
        // Get the typed data (second element in the array)
        let typedData = paramsArray[1]
        let typedDataJson: String
        
        if let typedDataString = typedData as? String {
            typedDataJson = typedDataString
        } else {
            let jsonData = try JSONSerialization.data(withJSONObject: typedData)
            typedDataJson = String(data: jsonData, encoding: .utf8) ?? ""
        }
        
        return try await signTypedData(jsonData: typedDataJson)
    }
    
    enum SignTypedDataError: Error, LocalizedError {
        case invalidParams
        
        var errorDescription: String? {
            switch self {
            case .invalidParams:
                return "Invalid typed data parameters"
            }
        }
    }
}

