import Foundation

// MARK: - TVFCollectorProtocol

public protocol TVFCollectorProtocol {
    func collect(
        rpcMethod: String,
        rpcParams: AnyCodable,
        chainID: Blockchain,
        rpcResult: RPCResult?,
        tag: Int
    ) -> TVFData?
}

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

// MARK: - EVMTVFCollector

class EVMTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    
    static let ETH_SEND_TRANSACTION = "eth_sendTransaction"
    static let ETH_SEND_RAW_TRANSACTION = "eth_sendRawTransaction"
    static let WALLET_SEND_CALLS = "wallet_sendCalls"
    
    // MARK: - Supported Methods
    
    private var supportedMethods: [String] {
        [Self.ETH_SEND_TRANSACTION, Self.ETH_SEND_RAW_TRANSACTION, Self.WALLET_SEND_CALLS]
    }
    
    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }
    
    // MARK: - Implementation
    
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        guard rpcMethod == Self.ETH_SEND_TRANSACTION else {
            return nil
        }
        do {
            // Attempt to decode the array of EthSendTransaction from AnyCodable
            let transactions = try rpcParams.get([EthSendTransaction].self)
            if let transaction = transactions.first,
               let callData = transaction.data,
               !callData.isEmpty,
               EVMTVFCollector.isValidContractData(callData) {
                // If the call data is valid contract call data, return the "to" address.
                if let to = transaction.to {
                    return [to]
                }
            }
        } catch {
            print("Failed to parse EthSendTransaction: \(error)")
        }
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }
        
        // For EVM methods, the response is the transaction hash as a string
        if let rawHash = try? anycodable.get(String.self) {
            return [rawHash]
        }
        return nil
    }
    
    // MARK: - Contract Data Validation
    
    /// Checks whether a given hex string (possibly prefixed with "0x") is valid contract call data.
    static func isValidContractData(_ data: String) -> Bool {
        var hex = data
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }
        // Require at least 73 hex characters:
        guard !hex.isEmpty, hex.count >= 73 else { return false }
        let methodId = hex.prefix(8)
        guard !methodId.isEmpty else { return false }
        let recipient = hex.dropFirst(8).prefix(64).drop(while: { $0 == "0" })
        guard !recipient.isEmpty else { return false }
        let amount = hex.dropFirst(72).drop(while: { $0 == "0" })
        guard !amount.isEmpty else { return false }
        return true
    }
}

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
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
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

// MARK: - TVFCollector

public class TVFCollector: TVFCollectorProtocol {

    // MARK: - Tag Enum
    enum Tag: Int {
        case sessionRequest = 1108
        case sessionResponse = 1109
    }

    private let chainCollectors: [ChainTVFCollector]
    
    public init() {
        self.chainCollectors = [
            EVMTVFCollector(),
            SolanaTVFCollector()
        ]
    }

    // MARK: - Single Public Method

    /// Collects TVF data based on the given parameters and the `tag`.
    ///
    /// - Parameters:
    ///   - rpcMethod: The RPC method (e.g., `"eth_sendTransaction"`).
    ///   - rpcParams: An `AnyCodable` containing arbitrary JSON or primitive content.
    ///   - chainID:   A `Blockchain` instance (e.g., `Blockchain("eip155:1")`).
    ///   - rpcResult: An optional `RPCResult` representing `.response(AnyCodable)` or `.error(...)`.
    ///   - tag:       Integer that should map to `.sessionRequest (1108)` or `.sessionResponse (1109)`.
    ///
    /// - Returns: `TVFData` if successful, otherwise `nil`.
    public func collect(
        rpcMethod: String,
        rpcParams: AnyCodable,
        chainID: Blockchain,
        rpcResult: RPCResult?,
        tag: Int
    ) -> TVFData? {

        // Convert the incoming 'tag' Int into the Tag enum
        guard let theTag = Tag(rawValue: tag) else {
            return nil
        }
        
        // Find a collector that supports this method
        guard let collector = chainCollectors.first(where: { $0.supportsMethod(rpcMethod) }) else {
            return nil
        }

        // Extract contract addresses if this is a request
        let contractAddresses = theTag == .sessionRequest ? 
            collector.extractContractAddresses(rpcMethod: rpcMethod, rpcParams: rpcParams) : nil

        // Parse transaction hashes if this is a response
        let txHashes = theTag == .sessionResponse ? 
            collector.parseTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult) : nil

        return TVFData(
            rpcMethods: [rpcMethod],
            chainId: chainID,
            txHashes: txHashes,
            contractAddresses: contractAddresses
        )
    }
}

#if DEBUG
public class TVFCollectorMock: TVFCollectorProtocol {
    public struct CollectCall {
        let method: String
        let params: AnyCodable
        let chainID: Blockchain?
        let result: RPCResult?
        let tag: Int
    }
    
    private(set) public var collectCalls: [CollectCall] = []
    public var mockResult: TVFData?
    
    public init(mockResult: TVFData? = nil) {
        self.mockResult = mockResult
    }
    
    public func collect(
        rpcMethod: String,
        rpcParams: AnyCodable,
        chainID: Blockchain,
        rpcResult: RPCResult?,
        tag: Int
    ) -> TVFData? {
        collectCalls.append(
            CollectCall(
                method: rpcMethod,
                params: rpcParams,
                chainID: chainID,
                result: RPCResult.response(AnyCodable("")),
                tag: tag
            )
        )
        return mockResult
    }
}
#endif
