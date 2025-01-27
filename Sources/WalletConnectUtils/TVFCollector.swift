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

// MARK: - TVFData

public struct TVFData {
    let rpcMethods: [String]?
    let chainId: Blockchain?
    let txHashes: [String]?
    let contractAddresses: [String]?
}

// MARK: - TVFCollector

public struct TVFCollector {

    // MARK: - Tag Enum
    enum Tag: Int {
        case sessionRequest = 1008
        case sessionResponse = 1009
    }

    // MARK: - Constants

    private static let ETH_SEND_TRANSACTION = "eth_sendTransaction"
    private static let ETH_SEND_RAW_TRANSACTION = "eth_sendRawTransaction"
    private static let WALLET_SEND_CALLS = "wallet_sendCalls"
    private static let SOLANA_SIGN_TRANSACTION = "solana_signTransaction"
    private static let SOLANA_SIGN_AND_SEND_TRANSACTION = "solana_signAndSendTransaction"
    private static let SOLANA_SIGN_ALL_TRANSACTION = "solana_signAllTransactions"

    // MARK: - Computed Properties

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

    // MARK: - Single Public Method

    /// Collects TVF data based on the given parameters and the `tag`.
    ///
    /// - Parameters:
    ///   - rpcMethod: The RPC method (e.g., `"eth_sendTransaction"`).
    ///   - rpcParams: An `AnyCodable` containing arbitrary JSON or primitive content.
    ///   - chainID:   A `Blockchain` instance (e.g., `Blockchain("eip155:1")`).
    ///   - rpcResult: A JSON/string for the RPC result (only needed if `tag == .sessionResponse`).
    ///   - tag:       Integer that should map to `.sessionRequest (1008)` or `.sessionResponse (1009)`.
    ///
    /// - Returns: `TVFData` if successful, otherwise `nil`.
    public func collect(
        rpcMethod: String,
        rpcParams: AnyCodable,
        chainID: Blockchain,
        rpcResult: String?,
        tag: Int
    ) -> TVFData? {

        // Convert the incoming 'tag' Int into the Tag enum
        guard let theTag = Tag(rawValue: tag) else {
            return nil
        }

        // 1. Ensure the method is recognized
        guard all.contains(rpcMethod) else {
            return nil
        }

        // 2. Gather contract addresses if this is eth_sendTransaction
        let contractAddresses = extractContractAddressesIfNeeded(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams
        )

        // 3. If this is a sessionResponse (1009), gather transaction hashes from rpcResult
        let txHashes: [String]? = {
            switch theTag {
            case .sessionRequest:
                return nil
            case .sessionResponse:
                return collectTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult)
            }
        }()

        return TVFData(
            rpcMethods: [rpcMethod],
            chainId: chainID,
            txHashes: txHashes,
            contractAddresses: contractAddresses
        )
    }

    // MARK: - Private Helpers

    /// Parse contract addresses from `rpcParams` if the method is `"eth_sendTransaction"`.
    private func extractContractAddressesIfNeeded(rpcMethod: String,
                                                  rpcParams: AnyCodable) -> [String]? {
        guard rpcMethod == Self.ETH_SEND_TRANSACTION else {
            return nil
        }
        do {
            // Attempt to decode the array of EthSendTransaction from the AnyCodable
            let transactions = try rpcParams.get([EthSendTransaction].self)
            if let firstTo = transactions.first?.to {
                return [firstTo]
            }
        } catch {
            print("Failed to parse EthSendTransaction: \(error)")
        }
        return nil
    }

    /// Parse transaction hashes/signatures from `rpcResult` for Solana/EVM/wallet calls.
    private func collectTxHashes(rpcMethod: String, rpcResult: String?) -> [String]? {
        // If rpcResult is nil, we can't parse anything
        guard let rpcResult = rpcResult else {
            return nil
        }

        do {
            switch rpcMethod {
            // EVM or wallet methods simply return the raw string as the transaction hash
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
