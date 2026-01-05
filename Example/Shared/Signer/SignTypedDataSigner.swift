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
    
    /// Sign EIP-712 typed data from params
    /// - Parameter params: JSON string containing either:
    ///   - The typed data directly: {"types": ..., "message": ...}
    ///   - An array format: [address, typedDataJson]
    /// - Returns: The signature as a hex string
    func signTypedDataFromParams(_ params: String) async throws -> String {
        print("[SignTypedDataSigner] Raw params: \(params)")
        
        let trimmed = params.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if params is already the typed data object (starts with {)
        if trimmed.hasPrefix("{") {
            print("[SignTypedDataSigner] Params is typed data object directly")
            return try await signTypedData(jsonData: params)
        }
        
        // Otherwise it's an array format [address, typedDataJson]
        if trimmed.hasPrefix("[") {
            print("[SignTypedDataSigner] Params is array format, extracting second element")
            let typedDataJson = try extractSecondElementFromJsonArray(params)
            print("[SignTypedDataSigner] Extracted typed data (full): \(typedDataJson)")
            return try await signTypedData(jsonData: typedDataJson)
        }
        
        throw SignTypedDataError.invalidParams
    }
    
    /// Extract the second element from a JSON array string without full parsing
    /// This preserves the exact JSON format of the element
    private func extractSecondElementFromJsonArray(_ jsonArray: String) throws -> String {
        // Find the start of the second element (after the first comma outside of strings)
        var inString = false
        var escapeNext = false
        var firstCommaIndex: String.Index?
        
        for (index, char) in jsonArray.enumerated() {
            if escapeNext {
                escapeNext = false
                continue
            }
            if char == "\\" {
                escapeNext = true
                continue
            }
            if char == "\"" {
                inString = !inString
                continue
            }
            if !inString && char == "," {
                firstCommaIndex = jsonArray.index(jsonArray.startIndex, offsetBy: index)
                break
            }
        }
        
        guard let commaIndex = firstCommaIndex else {
            throw SignTypedDataError.invalidParams
        }
        
        // Get the substring after the first comma
        let afterComma = String(jsonArray[jsonArray.index(after: commaIndex)...])
        let trimmed = afterComma.trimmingCharacters(in: .whitespaces)
        
        // If it starts with {, find the matching closing brace (accounting for strings)
        if trimmed.hasPrefix("{") {
            var braceCount = 0
            var inStr = false
            var escape = false
            var endOffset = 0
            
            for (index, char) in trimmed.enumerated() {
                if escape {
                    escape = false
                    continue
                }
                if char == "\\" {
                    escape = true
                    continue
                }
                if char == "\"" {
                    inStr = !inStr
                    continue
                }
                if !inStr {
                    if char == "{" {
                        braceCount += 1
                    } else if char == "}" {
                        braceCount -= 1
                        if braceCount == 0 {
                            endOffset = index + 1
                            break
                        }
                    }
                }
            }
            
            let objectJson = String(trimmed.prefix(endOffset))
            return objectJson
        }
        
        throw SignTypedDataError.invalidParams
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

