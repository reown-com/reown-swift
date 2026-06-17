import Foundation
import Web3

/// Generic EIP-712 typed-data signer.
///
/// Computes the EIP-712 digest locally via `EIP712TypedData` and signs it with
/// Web3.swift. Yttrium's `EvmSigningClient.signTypedData` is hardcoded for
/// ERC-3009 payloads (requires `from/to/value/validAfter/validBefore/nonce` in
/// the message) and so cannot be used for generic typed data like Permit2.
final class SignTypedDataSigner {

    private let privateKey: String

    init(privateKey: String) {
        self.privateKey = privateKey
    }

    /// Sign EIP-712 typed data from params.
    /// Handles both formats:
    /// - Direct typed data: `{"types": ..., "message": ...}`
    /// - Array format: `[address, typedData]` (standard `eth_signTypedData_v4` params)
    ///
    /// Returns a JSON string `{"v": Int, "r": "0x...", "s": "0x..."}` to match
    /// the contract expected by `ETHSigner.signTypedData`.
    func signTypedDataFromParams(_ params: String) async throws -> String {
        let typedDataJson = try extractTypedData(from: params)
        let typedData = try EIP712TypedData.parse(jsonString: typedDataJson)
        let digest = try typedData.digest()

        let key = try EthereumPrivateKey(hexPrivateKey: privateKey)
        let (v, r, s) = try key.sign(hash: digest)

        let response: [String: Any] = [
            "v": Int(v) + 27,
            "r": "0x" + Self.hexPadded(r),
            "s": "0x" + Self.hexPadded(s)
        ]
        let data = try JSONSerialization.data(withJSONObject: response, options: [])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func extractTypedData(from params: String) throws -> String {
        guard let data = params.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            throw SignTypedDataError.invalidParams
        }

        if json is [String: Any] {
            return params
        }

        if let array = json as? [Any], array.count >= 2 {
            let typedData = array[1]

            if let typedDataString = typedData as? String {
                return typedDataString
            }

            if typedData is [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: typedData, options: .sortedKeys)
                return String(data: jsonData, encoding: .utf8) ?? ""
            }
        }

        throw SignTypedDataError.invalidParams
    }

    private static func hexPadded(_ bytes: [UInt8]) -> String {
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        if hex.count >= 64 { return String(hex.suffix(64)) }
        return String(repeating: "0", count: 64 - hex.count) + hex
    }

    enum SignTypedDataError: Error, LocalizedError {
        case invalidParams

        var errorDescription: String? {
            "Invalid typed data parameters"
        }
    }
}
