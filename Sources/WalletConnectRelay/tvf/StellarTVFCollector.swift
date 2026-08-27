import Foundation
import CryptoKit

// MARK: - Supporting Models

struct StellarSignXDRResult: Codable {
    let signedXDR: String
    let signerAddress: String?
}

struct StellarSignAndSubmitXDRResult: Codable {
    let tx_hash: String?
    let signedXDR: String?
}

// MARK: - StellarTVFCollector

class StellarTVFCollector: ChainTVFCollector {
    // MARK: - Constants

    static let STELLAR_SIGN_XDR = "stellar_signXDR"
    static let STELLAR_SIGN_AND_SUBMIT_XDR = "stellar_signAndSubmitXDR"

    private static let pubnetPassphrase = "Public Global Stellar Network ; September 2015"
    private static let testnetPassphrase = "Test SDF Network ; September 2015"

    // XDR EnvelopeType discriminants
    private static let envelopeTypeTxV0: UInt32 = 0
    private static let envelopeTypeTx: UInt32 = 2
    private static let envelopeTypeTxFeeBump: UInt32 = 5

    // DecoratedSignature with an ed25519 signature: hint (4) + length (4, =64) + signature (64)
    private static let decoratedSignatureLength = 72
    private static let ed25519SignatureLength: UInt32 = 64
    private static let maxEnvelopeSignatures = 20

    // MARK: - Supported Methods

    private var supportedMethods: [String] {
        [Self.STELLAR_SIGN_XDR, Self.STELLAR_SIGN_AND_SUBMIT_XDR]
    }

    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }

    // MARK: - Implementation

    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // Stellar doesn't extract contract addresses for TVF in this implementation
        return nil
    }

    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }

        // Only process Stellar transaction methods
        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }

        // `rpcResult` already holds the unwrapped JSON-RPC `result` value — the `result`
        // key is stripped during RPCResponse decoding — so decode directly off `anycodable`,
        // matching the Solana/EVM collectors and the JS reference implementation.
        switch rpcMethod {
        case Self.STELLAR_SIGN_AND_SUBMIT_XDR:
            if let result = try? anycodable.get(StellarSignAndSubmitXDRResult.self),
               let txHash = result.tx_hash {
                return [txHash]
            }
            return nil

        case Self.STELLAR_SIGN_XDR:
            guard let result = try? anycodable.get(StellarSignXDRResult.self) else {
                return nil
            }
            let chain = extractChain(from: rpcParams)
            return Self.computeTransactionHash(signedXDR: result.signedXDR, chain: chain).map { [$0] }

        default:
            return nil
        }
    }

    private func extractChain(from rpcParams: AnyCodable?) -> String? {
        guard let rpcParams = rpcParams,
              let params = try? rpcParams.get([String: AnyCodable].self),
              let chainAny = params["chain"],
              let chain = try? chainAny.get(String.self) else {
            return nil
        }
        return chain
    }

    // MARK: - Hash Computation

    /// Computes the Stellar transaction hash from a base64-encoded, signed TransactionEnvelope XDR
    /// as `sha256(network_id || envelope_type || transaction_body)`. Signatures are computed over
    /// the hash, so the trailing signature array is stripped rather than hashed. For fee-bump
    /// envelopes this yields the canonical fee-bump hash.
    ///
    /// - Parameters:
    ///   - signedXDR: base64-encoded TransactionEnvelope XDR (V0, V1 or fee-bump)
    ///   - chain: CAIP-2 chain id (`stellar:pubnet` / `stellar:testnet`), defaults to pubnet
    /// - Returns: lowercase hex transaction hash (64 chars), or nil for malformed envelopes
    static func computeTransactionHash(signedXDR: String, chain: String?) -> String? {
        guard let bytes = Data(base64Encoded: signedXDR), bytes.count >= 8 else {
            return nil
        }

        let discriminant = readUInt32BE(bytes, 0)
        let envelopeType: UInt32
        let bodyStart: Int
        switch discriminant {
        case envelopeTypeTxV0:
            // V0 transactions are hashed as ENVELOPE_TYPE_TX over the envelope bytes INCLUDING
            // the leading 4 zero bytes - they double as the legacy AccountID key-type tag
            envelopeType = envelopeTypeTx
            bodyStart = 0
        case envelopeTypeTx:
            envelopeType = envelopeTypeTx
            bodyStart = 4
        case envelopeTypeTxFeeBump:
            envelopeType = envelopeTypeTxFeeBump
            bodyStart = 4
        default:
            return nil
        }

        guard let signatureArrayOffset = findSignatureArrayOffset(bytes) else {
            return nil
        }

        let reference = chain?.components(separatedBy: ":").last ?? "pubnet"
        let passphrase: String
        switch reference {
        case "pubnet": passphrase = pubnetPassphrase
        case "testnet": passphrase = testnetPassphrase
        default: return nil
        }

        let networkId = Data(SHA256.hash(data: Data(passphrase.utf8)))
        var payload = networkId
        payload.append(contentsOf: [0, 0, 0, UInt8(envelopeType)])
        payload.append(bytes.subdata(in: bodyStart..<signatureArrayOffset))

        return SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    }

    /// Locates the start of the trailing `DecoratedSignature signatures<20>` XDR array without
    /// parsing the transaction body. Assumes ed25519 signatures (fixed 72-byte entries), which is
    /// what the WalletConnect Stellar RPC spec mandates wallets emit.
    private static func findSignatureArrayOffset(_ bytes: Data) -> Int? {
        // Scan from the maximum count downward: a real multi-signature array must be found
        // before the vacuously-matching zero count, which would otherwise win whenever a
        // signature happens to end in four zero bytes.
        for signatureCount in stride(from: maxEnvelopeSignatures, through: 0, by: -1) {
            let offset = bytes.count - 4 - decoratedSignatureLength * signatureCount
            if offset < 4 { continue }
            if readUInt32BE(bytes, offset) != UInt32(signatureCount) { continue }

            var isValid = true
            for i in 0..<signatureCount {
                let entryOffset = offset + 4 + decoratedSignatureLength * i
                // each entry's signature length field must be exactly 64 (ed25519)
                if readUInt32BE(bytes, entryOffset + 4) != ed25519SignatureLength {
                    isValid = false
                    break
                }
            }
            if isValid { return offset }
        }
        return nil
    }

    private static func readUInt32BE(_ bytes: Data, _ offset: Int) -> UInt32 {
        let index = bytes.startIndex + offset
        return (UInt32(bytes[index]) << 24)
            | (UInt32(bytes[index + 1]) << 16)
            | (UInt32(bytes[index + 2]) << 8)
            | UInt32(bytes[index + 3])
    }
}
