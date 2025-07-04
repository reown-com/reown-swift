import Foundation

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
          //  print("Failed to parse EthSendTransaction: \(error)")
        }
        return nil
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
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
