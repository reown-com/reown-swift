import Foundation

// MARK: - Supporting Models

struct EthSendTransaction: Codable {
    let from: String?
    let to: String?
    let data: String?   // This field contains the call data
    let value: String?
}

struct SolanaSignTransactionResult: Codable {
    let signature: String?
}

struct SolanaSignAndSendTransactionResult: Codable {
    let signature: String?
}

struct SolanaSignAllTransactionsResult: Codable {
    let transactions: [String]?
}

struct TronSignTransactionResult: Codable {
    let txID: String
    let signature: [String]
    let raw_data: RawData?
    
    struct RawData: Codable {
        let contract: [Contract]?
        
        struct Contract: Codable {
            let parameter: Parameter?
            let type: String?
            
            struct Parameter: Codable {
                let value: Value?
                
                struct Value: Codable {
                    let contract_address: String?
                    let owner_address: String?
                    let data: String?
                    
                    enum CodingKeys: String, CodingKey {
                        case contract_address = "contract_address"
                        case owner_address
                        case data
                    }
                }
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case txID = "txID"
        case signature
        case raw_data = "raw_data"
    }
}

// Model for Tron transaction request parameters
struct TronTransaction: Codable {
    let raw_data: RawData?
    
    enum CodingKeys: String, CodingKey {
        case raw_data = "raw_data"
    }
    
    struct RawData: Codable {
        let contract: [Contract]?
        
        struct Contract: Codable {
            let parameter: Parameter?
            let type: String?
            
            struct Parameter: Codable {
                let value: Value?
                
                struct Value: Codable {
                    let contract_address: String?
                    let owner_address: String?
                    let data: String?
                    
                    enum CodingKeys: String, CodingKey {
                        case contract_address = "contract_address"
                        case owner_address
                        case data
                    }
                }
            }
        }
    }
}

// MARK: - TVFData

public struct TVFData {
    public let rpcMethods: [String]?
    public let chainId: Blockchain?
    public let txHashes: [String]?
    public let contractAddresses: [String]?
}

// MARK: - ChainTVFCollector Protocol

protocol ChainTVFCollector {
    func supportsMethod(_ method: String) -> Bool
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]?
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]?
}

// MARK: - ChainTVFCollector Extension

extension ChainTVFCollector {
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        return parseTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult, rpcParams: nil)
    }
} 
