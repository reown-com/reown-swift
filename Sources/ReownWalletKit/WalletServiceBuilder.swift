import Foundation

/// A builder class for creating wallet service JSON structures
public class WalletServiceBuilder {
    private let projectId: String
    
    public init(projectId: String) {
        self.projectId = projectId
    }
    
    /// Builds a wallet service JSON structure with the specified methods
    /// - Parameter methods: The wallet service methods to include
    /// - Returns: A JSON string representing the wallet service configuration
    public func buildWalletService(_ methods: [String]) -> String {
        let url = "https://rpc.walletconnect.org/v1/wallet?projectId=\(projectId)&st=wkca&sv=\(EnvironmentInfo.sdkName)"
        
        let walletService: [String: Any] = [
            "walletService": [
                [
                    "url": url,
                    "methods": methods
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: walletService, options: [.prettyPrinted, .sortedKeys])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            print("Error serializing JSON: \(error)")
        }
        
        // Return an empty JSON structure as fallback
        return "{\"walletService\":[{\"url\":\"\(url)\",\"methods\":[]}]}"
    }
} 