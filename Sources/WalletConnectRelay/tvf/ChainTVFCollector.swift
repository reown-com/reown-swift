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
    let txID: String?
    let signature: [String]?
    let raw_data: AnyCodable?
    
    enum CodingKeys: String, CodingKey {
        case txID = "txID"
        case signature
        case raw_data = "raw_data"
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
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]?
} 