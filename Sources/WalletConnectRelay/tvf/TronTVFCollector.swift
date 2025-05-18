import Foundation

// MARK: - TronTVFCollector

class TronTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let TRON_SIGN_TRANSACTION = "tron_signTransaction"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.TRON_SIGN_TRANSACTION]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // Tron doesn't extract contract addresses in the current implementation
        // This could be enhanced in the future to extract contract addresses from transaction data
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // Only process Tron sign transaction method
        guard rpcMethod == Self.TRON_SIGN_TRANSACTION else {
            return nil
        }
        
        // For Tron, we need to extract the txID from the response
        // This is different from EVM chains where the transaction hash is returned directly
        
        // First, try to extract from the result wrapper that contains the txID
        do {
            // Try to extract from result wrapper first (nested format)
            let result = try anycodable.get([String: AnyCodable].self)
            if let resultValue = result["result"] {
                do {
                    let decoded = try resultValue.get(TronSignTransactionResult.self)
                    if let txID = decoded.txID {
                        return [txID]
                    }
                } catch {
                    print("Error decoding nested Tron result: \(error)")
                    // Continue to try the direct format
                }
            }
            
            // Fallback: try to decode directly from the response
            return nil
        } catch {
            // If we couldn't parse as dictionary, try direct format
            do {
                let decoded = try anycodable.get(TronSignTransactionResult.self)
                if let txID = decoded.txID {
                    return [txID]
                }
                return nil
            } catch {
                print("Error processing Tron transaction: \(error)")
                return nil
            }
        }
    }
} 
