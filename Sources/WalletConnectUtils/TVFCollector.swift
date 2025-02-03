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
    public let rpcMethods: [String]?
    public let chainId: Blockchain?
    public let txHashes: [String]?
    public let contractAddresses: [String]?
}

// MARK: - TVFCollector

public struct TVFCollector {

    // MARK: - Tag Enum
    enum Tag: Int {
        case sessionRequest = 1108
        case sessionResponse = 1109
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
        [Self.ETH_SEND_TRANSACTION, Self.ETH_SEND_RAW_TRANSACTION]
    }

    private var solana: [String] {
        [Self.SOLANA_SIGN_TRANSACTION, Self.SOLANA_SIGN_AND_SEND_TRANSACTION, Self.SOLANA_SIGN_ALL_TRANSACTION]
    }

    private var wallet: [String] {
        [Self.WALLET_SEND_CALLS]
    }

    private var all: [String] {
        evm + solana + wallet
    }

    public init() {}

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

        // 1. Ensure the method is recognized
        guard all.contains(rpcMethod) else {
            return nil
        }

        // 2. Gather contract addresses if this is eth_sendTransaction
        let contractAddresses = extractContractAddressesIfNeeded(
            rpcMethod: rpcMethod,
            rpcParams: rpcParams
        )

        // 3. If this is a sessionResponse (1109), gather transaction hashes from rpcResult
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
            // Attempt to decode the array of EthSendTransaction from AnyCodable
            let transactions = try rpcParams.get([EthSendTransaction].self)
            if let firstTo = transactions.first?.to {
                // Use our contract data check: if it is valid contract call data, then return it.
                if TVFCollector.isValidContractData(firstTo) {
                    return [firstTo]
                } else {
                    return []
                }
            }
        } catch {
            print("Failed to parse EthSendTransaction: \(error)")
        }
        return nil
    }

    /// Parse transaction hashes/signatures from `rpcResult` for Solana/EVM/wallet calls.
    private func collectTxHashes(rpcMethod: String, rpcResult: RPCResult?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult else {
            return nil
        }
        switch rpcResult {
        case .error(_):
            return nil
        case .response(let anycodable):
            return parseTxHashes(forMethod: rpcMethod, from: anycodable)
        }
    }

    /// Decodes the actual transaction hash(es) from the given `AnyCodable` response value.
    private func parseTxHashes(forMethod method: String, from anycodable: AnyCodable) -> [String]? {
        do {
            switch method {
            // EVM or wallet methods return the raw string as the transaction hash
            case _ where evm.contains(method) || wallet.contains(method):
                if let rawHash = try? anycodable.get(String.self) {
                    return [rawHash]
                }
                return nil

            case Self.SOLANA_SIGN_TRANSACTION:
                let decoded = try anycodable.get(SolanaSignTransactionResult.self)
                return decoded.signature.map { [$0] }

            case Self.SOLANA_SIGN_AND_SEND_TRANSACTION:
                let decoded = try anycodable.get(SolanaSignAndSendTransactionResult.self)
                return decoded.signature.map { [$0] }

            case Self.SOLANA_SIGN_ALL_TRANSACTION:
                let decoded = try anycodable.get(SolanaSignAllTransactionsResult.self)
                return decoded.transactions

            default:
                return nil
            }
        } catch {
            print("Error processing \(method): \(error)")
            return nil
        }
    }
}

// MARK: - Contract Data Check

extension TVFCollector {
    /// Checks whether a given hex string (possibly prefixed with "0x") is valid contract call data.
    public static func isValidContractData(_ data: String) -> Bool {
        var hex = data
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }
        // Ensure there are at least 136 hex characters (8 for method, 64 for recipient, 64 for amount)
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
