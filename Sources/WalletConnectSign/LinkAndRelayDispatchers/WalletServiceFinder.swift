import Foundation

/// Class responsible for finding wallet services based on scoped properties
final class WalletServiceFinder {
    
    private let logger: ConsoleLogging
    
    init(logger: ConsoleLogging) {
        self.logger = logger
    }
    
    /// Finds a matching wallet service URL for the given request based on scopedProperties
    func findMatchingWalletService(for request: Request, in session: WCSession) -> URL? {
        guard let scopedProperties = session.scopedProperties else { return nil }
        
        // Check for exact chain match first (e.g., "eip155:1")
        let chainKey = request.chainId.absoluteString
        if let matchingService = findWalletService(for: request.method, in: scopedProperties, under: chainKey) {
            return matchingService
        }
        
        // Check for namespace match (e.g., "eip155" for any eip155 chain)
        let chainId = request.chainId
        if let matchingService = findWalletService(for: request.method, in: scopedProperties, under: chainId.namespace) {
            return matchingService
        }
        
        return nil
    }
    
    /// Finds a wallet service that supports the given method in the specified scope
    func findWalletService(for method: String, in scopedProperties: [String: String], under key: String) -> URL? {
        guard let scopeJSON = scopedProperties[key],
              let scopeData = scopeJSON.data(using: .utf8) else {
            return nil
        }
        
        do {
            // Parse the JSON data
            guard let scopeDict = try JSONSerialization.jsonObject(with: scopeData) as? [String: Any],
                  let walletServices = scopeDict["walletService"] as? [[String: Any]] else {
                return nil
            }
            
            // Find a service that supports the requested method
            for service in walletServices {
                guard let url = service["url"] as? String,
                      let methods = service["methods"] as? [String],
                      methods.contains(method),
                      let serviceURL = URL(string: url) else {
                    continue
                }
                
                return serviceURL
            }
        } catch {
            logger.error("Failed to parse scopedProperties JSON: \(error)")
        }
        
        return nil
    }
} 