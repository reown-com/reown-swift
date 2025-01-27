import Foundation

// MARK: - Supporting Models

struct EthSendTransaction: Codable {
    let from: String?
    let to: String?
    let data: String?
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

// MARK: - CollectionResult

/// A structure for returning the collection result from TVFCollector.
struct CollectionResult {
    let methods: [String]
    let contractAddresses: [String]?
    let chainId: String
}

// MARK: - TVFCollector

struct TVFCollector {
    // MARK: Constants

    private static let ETH_SEND_TRANSACTION = "eth_sendTransaction"
    private static let ETH_SEND_RAW_TRANSACTION = "eth_sendRawTransaction"
    private static let WALLET_SEND_CALLS = "wallet_sendCalls"
    private static let SOLANA_SIGN_TRANSACTION = "solana_signTransaction"
    private static let SOLANA_SIGN_AND_SEND_TRANSACTION = "solana_signAndSendTransaction"
    private static let SOLANA_SIGN_ALL_TRANSACTION = "solana_signAllTransactions"

    // MARK: Computed Properties

    private var evm: [String] {
        [Self.ETH_SEND_TRANSACTION,
         Self.ETH_SEND_RAW_TRANSACTION]
    }

    private var solana: [String] {
        [Self.SOLANA_SIGN_TRANSACTION,
         Self.SOLANA_SIGN_AND_SEND_TRANSACTION,
         Self.SOLANA_SIGN_ALL_TRANSACTION]
    }

    private var wallet: [String] {
        [Self.WALLET_SEND_CALLS]
    }

    private var all: [String] {
        evm + solana + wallet
    }

    // MARK: - Core Methods

    /// Attempts to collect relevant data from the provided parameters.
    ///
    /// - Parameters:
    ///   - rpcMethod: The RPC method string.
    ///   - rpcParams: A JSON string containing parameters.
    ///   - chainId: The chain ID.
    /// - Returns: A `CollectionResult` if the method is recognized, otherwise `nil`.
    func collect(rpcMethod: String,
                 rpcParams: String,
                 chainId: String) -> CollectionResult? {

        // If the method is not recognized, return nil
        guard all.contains(rpcMethod) else {
            return nil
        }

        // Attempt to decode addresses (EVM use-case)
        var contractAddresses: [String]? = nil

        switch rpcMethod {
        case Self.ETH_SEND_TRANSACTION:
            // Try to decode JSON array of EthSendTransaction
            guard let data = rpcParams.data(using: .utf8) else { break }
            do {
                let transactions = try JSONDecoder().decode([EthSendTransaction].self, from: data)
                // Use the first "to" address if present
                if let firstTo = transactions.first?.to {
                    contractAddresses = [firstTo]
                }
            } catch {
                // If decoding fails, we'll leave contractAddresses as nil
            }
        default:
            break
        }

        return CollectionResult(
            methods: [rpcMethod],
            contractAddresses: contractAddresses,
            chainId: chainId
        )
    }

    /// Collects transaction hashes from an RPC result if possible.
    ///
    /// - Parameters:
    ///   - rpcMethod: The RPC method string.
    ///   - rpcResult: A JSON string containing the result.
    /// - Returns: An array of hashes or signatures, or nil if none found.
    func collectTxHashes(rpcMethod: String,
                         rpcResult: String) -> [String]? {

        do {
            switch rpcMethod {
            // EVM or wallet methods simply return the raw result as the transaction hash
            case _ where evm.contains(rpcMethod) || wallet.contains(rpcMethod):
                return [rpcResult]

            case Self.SOLANA_SIGN_TRANSACTION:
                guard let data = rpcResult.data(using: .utf8) else { return nil }
                let decoded = try JSONDecoder().decode(SolanaSignTransactionResult.self, from: data)
                return decoded.signature.map { [$0] }

            case Self.SOLANA_SIGN_AND_SEND_TRANSACTION:
                guard let data = rpcResult.data(using: .utf8) else { return nil }
                let decoded = try JSONDecoder().decode(SolanaSignAndSendTransactionResult.self, from: data)
                return decoded.signature.map { [$0] }

            case Self.SOLANA_SIGN_ALL_TRANSACTION:
                guard let data = rpcResult.data(using: .utf8) else { return nil }
                let decoded = try JSONDecoder().decode(SolanaSignAllTransactionsResult.self, from: data)
                return decoded.transactions

            default:
                return nil
            }
        } catch {
            print("Error processing \(rpcMethod): \(error)")
            return nil
        }
    }
} 
