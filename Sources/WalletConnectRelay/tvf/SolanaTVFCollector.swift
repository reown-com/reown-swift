import Foundation

// MARK: - SolanaTVFCollector

class SolanaTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let SOLANA_SIGN_TRANSACTION = "solana_signTransaction"
    static let SOLANA_SIGN_AND_SEND_TRANSACTION = "solana_signAndSendTransaction"
    static let SOLANA_SIGN_ALL_TRANSACTION = "solana_signAllTransactions"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.SOLANA_SIGN_TRANSACTION, Self.SOLANA_SIGN_AND_SEND_TRANSACTION, Self.SOLANA_SIGN_ALL_TRANSACTION]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // Solana doesn't extract contract addresses in the current implementation
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        do {
            switch rpcMethod {
            case Self.SOLANA_SIGN_TRANSACTION:
                let decoded = try anycodable.get(SolanaSignTransactionResult.self)
                return decoded.signature.map { [$0] }
                
            case Self.SOLANA_SIGN_AND_SEND_TRANSACTION:
                let decoded = try anycodable.get(SolanaSignAndSendTransactionResult.self)
                return decoded.signature.map { [$0] }
                
            case Self.SOLANA_SIGN_ALL_TRANSACTION:
                let decoded = try anycodable.get(SolanaSignAllTransactionsResult.self)
                if let transactions = decoded.transactions {
                    var txHashes = [String]()
                    for transaction in transactions {
                        do {
                            let signature = try SolanaSignatureExtractor.extractSignature(from: transaction)
                            txHashes.append(signature)
                        } catch {
                            print("Error extracting signature from transaction: \(error)")
                        }
                    }
                    return txHashes.isEmpty ? nil : txHashes
                }
                return nil
                
            default:
                return nil
            }
        } catch {
            print("Error processing \(rpcMethod): \(error)")
            return nil
        }
    }
} 