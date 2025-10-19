import Foundation
import Commons
import Web3
import WalletConnectSign
import YttriumUtilsWrapper

struct ETHSigner {
    enum Errors: LocalizedError {
        case invalidTransactionParams

        var errorDescription: String? {
            switch self {
            case .invalidTransactionParams:
                return "Invalid parameters for eth_sendTransaction"
            }
        }
    }

    private struct EthSendTransactionParams: Codable {
        let from: String?
        let to: String?
        let value: String?
        let data: String?
        let gas: String?
        let gasLimit: String?
        let gasPrice: String?
        let maxFeePerGas: String?
        let maxPriorityFeePerGas: String?
        let nonce: String?
    }

    private static let evmSigningClient: EvmSigningClient = {
        let metadata = PulseMetadata(
            url: nil,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            sdkVersion: "reown-swift-\(EnvironmentInfo.sdkName)",
            sdkPlatform: "mobile"
        )
        return EvmSigningClient(projectId: InputConfig.projectId, pulseMetadata: metadata)
    }()

    private let importAccount: ImportAccount

    init(importAccount: ImportAccount) {
        self.importAccount = importAccount
    }

    var address: String {
        return privateKey.address.hex(eip55: true)
    }

    private var privateKey: EthereumPrivateKey {
        return try! EthereumPrivateKey(hexPrivateKey: importAccount.privateKey)
    }

    func personalSign(_ params: AnyCodable) -> AnyCodable {
        let params = try! params.get([String].self)
        let messageToSign = params[0]

        // Determine if the message is hex-encoded or plain text
        let dataToSign: [UInt8]
        if messageToSign.hasPrefix("0x") {
            // Hex-encoded message, remove "0x" and convert
            let messageData = Data(hex: String(messageToSign.dropFirst(2)))
            dataToSign = dataToHash(messageData)
        } else {
            // Plain text message, convert directly to data
            let messageData = Data(messageToSign.utf8)
            dataToSign = dataToHash(messageData)
        }

        // Sign the data
        let (v, r, s) = try! privateKey.sign(message: .init(Data(dataToSign)))
        let result = "0x" + r.toHexString() + s.toHexString() + String(v + 27, radix: 16)
        return AnyCodable(result)
    }

    func signHash(_ hashToSign: String) throws -> String {

        let dataToSign: [UInt8]
        if hashToSign.hasPrefix("0x") {
            // Hex-encoded message, remove "0x" and convert
            let messageData = Data(hex: String(hashToSign.dropFirst(2)))
            dataToSign = Array(messageData)
        } else {
            // Plain text message, convert directly to data
            let messageData = Data(hashToSign.utf8)
            dataToSign = Array(messageData)
        }

        let (v, r, s) = try! privateKey.sign(hash: dataToSign)
        let result = "0x" + r.toHexString() + s.toHexString() + String(v + 27, radix: 16)
        return result
    }

    func signTypedData(_ params: AnyCodable) -> AnyCodable { // TODO: implement typed data signing
        let result = "0x4355c47d63924e8a72e509b65029052eb6c299d53a04e167c5775fd466751c9d07299936d304c153f6443dfa05f40ff007d72911b6f72307f996231605b915621c"
        return AnyCodable(result)
    }

    func sendTransaction(request: Request) async throws -> AnyCodable {
        guard let tx = try request.params.get([EthSendTransactionParams].self).first else {
            throw Errors.invalidTransactionParams
        }

        let fromAddress = tx.from?.isEmpty == false ? tx.from! : address
        let transactionParams = SignAndSendParams(
            chainId: request.chainId.absoluteString,
            from: normalizeAddress(fromAddress) ?? fromAddress,
            to: normalizeAddress(tx.to),
            value: ensureHexPrefix(tx.value ?? "0x0"),
            data: normalizedDataHex(tx.data),
            gasLimit: ensureHexPrefix(coalesce(tx.gasLimit, tx.gas)),
            maxFeePerGas: ensureHexPrefix(coalesce(tx.maxFeePerGas, tx.gasPrice)),
            maxPriorityFeePerGas: ensureHexPrefix(tx.maxPriorityFeePerGas),
            nonce: ensureHexPrefix(tx.nonce)
        )

        let signer = ensureHexPrefix(importAccount.privateKey)
        let result = try await Self.evmSigningClient.signAndSend(
            params: transactionParams,
            signer: signer
        )

        return AnyCodable(result.transactionHash)
    }

    private func dataToHash(_ data: Data) -> [UInt8] {
        let prefix = "\u{19}Ethereum Signed Message:\n"
        let prefixData = (prefix + String(data.count)).data(using: .utf8)!
        let prefixedMessageData = prefixData + data
        return Array(prefixedMessageData)
    }

    private func ensureHexPrefix(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        if value.hasPrefix("0x") || value.hasPrefix("0X") {
            return value.lowercased().hasPrefix("0x") ? value : "0x" + value.dropFirst(2)
        }
        return "0x" + value
    }

    private func ensureHexPrefix(_ value: String) -> String {
        return ensureHexPrefix(Optional(value)) ?? value
    }

    private func normalizedDataHex(_ value: String?) -> String? {
        guard let value = ensureHexPrefix(value) else {
            return "0x"
        }
        return value
    }

    private func normalizeAddress(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        return ensureHexPrefix(value)
    }

    private func coalesce(_ values: String?...) -> String? {
        for value in values {
            if let value, !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
