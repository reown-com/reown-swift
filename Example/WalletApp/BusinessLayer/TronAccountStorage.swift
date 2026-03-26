import Foundation
import ReownWalletKit
import YttriumUtilsWrapper

class TronAccountStorage {
    enum Errors: Error {
        case addressUnavailable
        case keypairGenerationFailed
    }

    static let privateKeyStorageKey = "tron_privateKey" // hex-encoded 32-byte secp256k1 private key
    static let publicKeyStorageKey = "tron_publicKey"   // hex-encoded compressed public key

    // Tron Chain IDs (CAIP-2 format)
    private let mainnetChainId: Blockchain = Blockchain("tron:0x2b6653dc")!
    private let shastaChainId: Blockchain = Blockchain("tron:0xcd8690dc")!
    private let nileChainId: Blockchain = Blockchain("tron:0x94a9059e")!

    // MARK: - Key Generation

    @discardableResult
    func generateAndSaveKeypair() -> Bool {
        let keypair = tronGenerateKeypair()
        guard !keypair.sk.isEmpty, !keypair.pk.isEmpty else { return false }
        UserDefaults.standard.set(keypair.sk, forKey: Self.privateKeyStorageKey)
        UserDefaults.standard.set(keypair.pk, forKey: Self.publicKeyStorageKey)
        return true
    }

    // MARK: - Key Storage

    @discardableResult
    func savePrivateKey(_ privateKeyHex: String) -> Bool {
        // Validate: should be 64 hex chars (32 bytes) for secp256k1
        let cleaned = privateKeyHex.hasPrefix("0x") ? String(privateKeyHex.dropFirst(2)) : privateKeyHex
        guard cleaned.count == 64, cleaned.allSatisfy({ $0.isHexDigit }) else { return false }
        UserDefaults.standard.set(cleaned, forKey: Self.privateKeyStorageKey)
        // Note: public key will be derived when needed via getAddress
        return true
    }

    func getPrivateKey() -> String? {
        return UserDefaults.standard.string(forKey: Self.privateKeyStorageKey)
    }

    func getPublicKey() -> String? {
        return UserDefaults.standard.string(forKey: Self.publicKeyStorageKey)
    }

    // MARK: - Address Derivation

    func getAddress(for chainId: Blockchain? = nil) -> String? {
        guard let sk = getPrivateKey() else { return nil }
        guard let pk = getPublicKey() else { return nil }

        let keypair = TronKeypair(sk: sk, pk: pk)
        do {
            let address = try tronGetAddress(keypair: keypair)
            return address.base58
        } catch {
            return nil
        }
    }

    func getCaip10Account(for chainId: Blockchain? = nil) -> ReownWalletKit.Account? {
        let resolvedChainId = chainId ?? mainnetChainId
        guard let address = getAddress(for: resolvedChainId) else { return nil }
        return Account(blockchain: resolvedChainId, address: address)
    }
}
