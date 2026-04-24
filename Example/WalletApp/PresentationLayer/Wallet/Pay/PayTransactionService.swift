import Foundation
import BigInt
import Web3
import WalletConnectPay

/// Mirrors `src/utils/PaymentTransactionUtil.ts` from RN PR #472.
/// Responsible for:
/// - Estimating the native-token cost of an approval transaction for summary UI.
/// - Signing and submitting an `eth_sendTransaction` action with fresh EIP-1559 fees.
/// - Polling `eth_getTransactionReceipt` until the tx lands (or times out).
struct PayTransactionService {
    private let projectId: String

    init(projectId: String) {
        self.projectId = projectId
    }

    // MARK: - Constants (mirror RN)

    private static let gasEstimationRpcTimeoutMs: UInt64 = 15_000
    private static let receiptPollIntervalMs: UInt64 = 1_500
    private static let receiptPollTimeoutMs: UInt64 = 120_000

    /// 20% gas-limit buffer applied to `eth_estimateGas` results to avoid
    /// `intrinsic gas too low` reverts on approval txs.
    private static let gasBufferNumerator: BigUInt = 120
    private static let gasBufferDenominator: BigUInt = 100

    /// Polygon mainnet + Amoy testnets — floor priority fee of 30 gwei.
    private static let priorityFeeFloorByChain: [String: BigUInt] = [
        "eip155:137":   BigUInt(30_000_000_000),
        "eip155:80001": BigUInt(30_000_000_000),
        "eip155:80002": BigUInt(30_000_000_000)
    ]

    /// Native token symbol by CAIP-2 chain id. Polygon intentionally uses POL
    /// (post-migration) rather than MATIC.
    private static let nativeSymbolByChainId: [String: String] = [
        "eip155:1":     "ETH",
        "eip155:10":    "ETH",
        "eip155:137":   "POL",
        "eip155:80001": "POL",
        "eip155:80002": "POL",
        "eip155:8453":  "ETH",
        "eip155:42161": "ETH",
        "eip155:11155111": "ETH",
        "eip155:84532":  "ETH"
    ]

    // MARK: - Public API

    /// Returns a short human-readable fee preview string, e.g. "~0.0034 POL".
    /// Returns `nil` if estimation fails for any reason.
    func estimateTransactionFee(action: Action) async -> String? {
        guard let payload = Self.decodePayload(from: action.walletRpc.params) else { return nil }

        let chainId = action.walletRpc.chainId
        let client = PayRPCClient(chainId: chainId, projectId: projectId)
        let symbol = Self.nativeSymbolByChainId[chainId] ?? "ETH"

        let request = RPCTxRequest(
            from: payload.from,
            to: payload.to,
            data: payload.data,
            value: payload.value
        )

        do {
            let gasLimitHex: String = try await Self.withTimeout(message: "eth_estimateGas") {
                try await client.estimateGas(request)
            }
            let latestBlock: RPCBlock = try await Self.withTimeout(message: "eth_getBlockByNumber") {
                try await client.getLatestBlock()
            }
            let priorityHex: String? = try? await Self.withTimeout(message: "eth_maxPriorityFeePerGas") {
                try await client.maxPriorityFeePerGas()
            }
            let gasPriceHex: String? = try? await Self.withTimeout(message: "eth_gasPrice") {
                try await client.gasPrice()
            }

            let rawGasLimit = Self.parseHex(gasLimitHex) ?? 0
            let gasLimit = Self.applyGasBuffer(rawGasLimit)
            let priority = Self.parseHex(priorityHex ?? "")
            let legacyGasPrice = Self.parseHex(gasPriceHex ?? "")

            let fees = Self.computeFees(
                chainId: chainId,
                baseFeeHex: latestBlock.baseFeePerGas,
                priorityFee: priority,
                legacyGasPrice: legacyGasPrice
            )
            let totalWei = gasLimit * fees.maxFee
            return Self.formatFee(weiTotal: totalWei, symbol: symbol)
        } catch {
            print("💳 [PayTx] estimateTransactionFee error: \(error)")
            return nil
        }
    }

    /// Signs and submits a fresh EIP-1559 transaction for the given action, then
    /// waits for the receipt. Returns the tx hash on success.
    @discardableResult
    func sendTransactionAndWait(action: Action, importAccount: ImportAccount) async throws -> String {
        guard let payload = Self.decodePayload(from: action.walletRpc.params) else {
            throw PayTxError.invalidPayload
        }
        let chainId = action.walletRpc.chainId
        guard let numericChainId = Self.numericChainId(from: chainId) else {
            throw PayTxError.unsupportedChainId(chainId)
        }
        let client = PayRPCClient(chainId: chainId, projectId: projectId)

        let privateKey = try EthereumPrivateKey(hexPrivateKey: importAccount.privateKey)

        let signerAddress = privateKey.address.hex(eip55: false)
        guard payload.from.lowercased() == signerAddress.lowercased() else {
            throw PayTxError.fromAddressMismatch(payload: payload.from, signer: signerAddress)
        }

        let estimateRequest = RPCTxRequest(
            from: payload.from,
            to: payload.to,
            data: payload.data,
            value: payload.value
        )

        let latestBlock = try await client.getLatestBlock()
        let priorityHex: String? = try? await client.maxPriorityFeePerGas()
        let gasPriceHex: String? = try? await client.gasPrice()
        let nonceHex = try await client.getTransactionCount(address: payload.from, block: "pending")
        let gasLimitHex = try await client.estimateGas(estimateRequest)

        let priority = Self.parseHex(priorityHex ?? "")
        let legacyGasPrice = Self.parseHex(gasPriceHex ?? "")
        let nonce = Self.parseHex(nonceHex) ?? 0
        let gasLimit = Self.applyGasBuffer(Self.parseHex(gasLimitHex) ?? 0)

        let fees = Self.computeFees(
            chainId: chainId,
            baseFeeHex: latestBlock.baseFeePerGas,
            priorityFee: priority,
            legacyGasPrice: legacyGasPrice
        )

        let txValue = Self.parseHex(payload.value ?? "0x0") ?? 0
        let dataBytes: Bytes
        if let dataHex = payload.data {
            let stripped = dataHex.hasPrefix("0x") ? String(dataHex.dropFirst(2)) : dataHex
            dataBytes = Bytes(hex: stripped)
        } else {
            dataBytes = []
        }
        let toAddress = try EthereumAddress(hex: payload.to, eip55: false)

        let tx = EthereumTransaction(
            nonce: EthereumQuantity(quantity: nonce),
            gasPrice: nil,
            maxFeePerGas: EthereumQuantity(quantity: fees.maxFee),
            maxPriorityFeePerGas: EthereumQuantity(quantity: fees.priority),
            gasLimit: EthereumQuantity(quantity: gasLimit),
            from: privateKey.address,
            to: toAddress,
            value: EthereumQuantity(quantity: txValue),
            data: EthereumData(dataBytes),
            accessList: [:],
            transactionType: .eip1559
        )

        let signed = try tx.sign(with: privateKey, chainId: EthereumQuantity(quantity: BigUInt(numericChainId)))
        let rawHex = try signed.rawTransaction().hex()

        let hash = try await client.sendRawTransaction(rawHex)
        try await waitForReceipt(hash: hash, client: client)
        return hash
    }

    // MARK: - Helpers

    private func waitForReceipt(hash: String, client: PayRPCClient) async throws {
        let deadline = Date().addingTimeInterval(Double(Self.receiptPollTimeoutMs) / 1_000)
        while Date() < deadline {
            let maybeReceipt = try? await client.getTransactionReceipt(hash: hash)
            if let receipt = maybeReceipt ?? nil {
                let statusOk = (Self.parseHex(receipt.status ?? "0x1") ?? 1) == 1
                if !statusOk {
                    throw PayTxError.txReverted(hash: hash)
                }
                return
            }
            try await Task.sleep(nanoseconds: Self.receiptPollIntervalMs * 1_000_000)
        }
        throw PayTxError.receiptTimeout(hash: hash)
    }

    /// EIP-1559 fee calculation mirroring `buildFreshTxRequest` in the RN util.
    private static func computeFees(
        chainId: String,
        baseFeeHex: String?,
        priorityFee: BigUInt?,
        legacyGasPrice: BigUInt?
    ) -> (maxFee: BigUInt, priority: BigUInt) {
        let oneGwei = BigUInt(1_000_000_000)
        var priority = priorityFee ?? oneGwei
        if let floor = priorityFeeFloorByChain[chainId] {
            priority = max(priority, floor)
        }

        let baseFee = parseHex(baseFeeHex ?? "") ?? 0
        var maxFee = baseFee * 2 + priority
        if let legacyGasPrice { maxFee = max(maxFee, legacyGasPrice) }
        maxFee = max(maxFee, priority)
        return (maxFee, priority)
    }

    private static func formatFee(weiTotal: BigUInt, symbol: String) -> String {
        let divisor = BigUInt(10).power(18)
        let wholePart = weiTotal / divisor
        let fractionalPart = weiTotal % divisor
        let native = Double(wholePart) + Double(fractionalPart) / pow(10.0, 18)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let digits = native >= 0.01 ? 4 : 6
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        let formatted = formatter.string(from: NSNumber(value: native)) ?? String(format: "%.6f", native)
        return "~\(formatted) \(symbol)"
    }

    private static func applyGasBuffer(_ gas: BigUInt) -> BigUInt {
        (gas * gasBufferNumerator) / gasBufferDenominator
    }

    private static func parseHex(_ hex: String) -> BigUInt? {
        guard !hex.isEmpty else { return nil }
        let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard !stripped.isEmpty else { return BigUInt(0) }
        return BigUInt(stripped, radix: 16)
    }

    private static func numericChainId(from caip2: String) -> Int? {
        let parts = caip2.split(separator: ":")
        guard parts.count == 2, parts[0] == "eip155" else { return nil }
        return Int(parts[1])
    }

    /// Wraps an async throwing operation with a timeout — throws `PayTxError.timeout` on expiry.
    static func withTimeout<T>(
        timeoutMs: UInt64 = gasEstimationRpcTimeoutMs,
        message: String,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T where T: Sendable {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutMs * 1_000_000)
                throw PayTxError.timeout(message)
            }
            let result = try await group.next()
            group.cancelAll()
            guard let result else { throw PayTxError.timeout(message) }
            return result
        }
    }

    // MARK: - Payload decoding

    private struct TxPayload: Decodable {
        let from: String
        let to: String
        let data: String?
        let value: String?
        let gas: String?
        let gasLimit: String?
    }

    private static func decodePayload(from paramsJson: String) -> TxPayload? {
        guard let data = paramsJson.data(using: .utf8) else { return nil }
        if let array = try? JSONDecoder().decode([TxPayload].self, from: data), let first = array.first {
            return first
        }
        return try? JSONDecoder().decode(TxPayload.self, from: data)
    }
}

enum PayTxError: Error, LocalizedError {
    case invalidPayload
    case unsupportedChainId(String)
    case timeout(String)
    case txReverted(hash: String)
    case receiptTimeout(hash: String)
    case fromAddressMismatch(payload: String, signer: String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload: return "Invalid eth_sendTransaction payload"
        case .unsupportedChainId(let id): return "Unsupported chain id: \(id)"
        case .timeout(let m): return "Timed out: \(m)"
        case .txReverted(let h): return "Transaction reverted: \(h)"
        case .receiptTimeout(let h): return "Timed out waiting for receipt \(h)"
        case .fromAddressMismatch(let p, let s):
            return "Payload sender \(p) does not match signer \(s)"
        }
    }
}
