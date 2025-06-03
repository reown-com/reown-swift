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
        guard rpcMethod == Self.TRON_SIGN_TRANSACTION else {
            return nil
        }
        
        // Decode as a TronTransaction
        if let transaction = try? rpcParams.get(TronTransaction.self), 
           let contractAddresses = extractContractAddressesFromTransaction(transaction) {
            return contractAddresses
        }
        
        return nil
    }
    
    // Helper method to extract contract addresses from a TronTransaction
    private func extractContractAddressesFromTransaction(_ transaction: TronTransaction) -> [String]? {
        guard let rawData = transaction.raw_data,
              let contracts = rawData.contract else {
            return nil
        }
        
        var contractAddresses = [String]()
        
        for contract in contracts {
            if let parameter = contract.parameter,
               let value = parameter.value,
               let contractAddress = value.contract_address {
                contractAddresses.append(contractAddress)
            }
        }
        
        return contractAddresses.isEmpty ? nil : contractAddresses
    }
    
    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
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
        
        // Extract from result wrapper (nested format)
        if let result = try? anycodable.get([String: AnyCodable].self),
           let resultValue = result["result"],
           let decoded = try? resultValue.get(TronSignTransactionResult.self) {
            return [decoded.txID]
        }
        return nil
    }
} 
