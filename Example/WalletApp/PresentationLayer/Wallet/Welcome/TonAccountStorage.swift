import Foundation
import ReownWalletKit
import YttriumUtilsWrapper
import CryptoKit

class TonAccountStorage {
    enum Errors: Error {
        case addressUnavailable
    }

    static let privateKeyStorageKey = "ton_privateKey" // base64-encoded 32-byte Ed25519 seed

    private let chainId: Blockchain = Blockchain("ton:-239")!

    @discardableResult
    func generateAndSaveKeypair() -> Bool {
        do {
            let cfg = TonClientConfig(networkId: chainId.absoluteString)
            let client = try TonClient(cfg: cfg)
            let keypair = client.generateKeypair()
            // Persist only the private seed; public key is always derived on demand
            UserDefaults.standard.set(keypair.sk, forKey: Self.privateKeyStorageKey)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func savePrivateKey(_ privateKeyBase64: String) -> Bool {
        // Enforce a single supported input format: base64-encoded 32-byte Ed25519 seed
        guard let data = Data(base64Encoded: privateKeyBase64), data.count == 32 else { return false }
        UserDefaults.standard.set(privateKeyBase64, forKey: Self.privateKeyStorageKey)
        return true
    }

    func getPrivateKey() -> String? {
        return UserDefaults.standard.string(forKey: Self.privateKeyStorageKey)
    }

    func getAddress() -> String? {
        guard let sk = getPrivateKey(), let pk = derivePublicKeyHex(from: sk) else { return nil }
        do {
            let cfg = TonClientConfig(networkId: chainId.absoluteString)
            let client = try TonClient(cfg: cfg)
            let identity = try client.getAddressFromKeypair(keypair: Keypair(sk: sk, pk: pk))
            return identity.friendlyEq
        } catch {
            return nil
        }
    }

    func getCaip10Account() -> ReownWalletKit.Account? {
        guard let address = getAddress() else { return nil }
        return Account(blockchain: chainId, address: address)!
    }
}

private extension TonAccountStorage {
    func derivePublicKeyHex(from privateKeyBase64: String) -> String? {
        guard let skData = Data(base64Encoded: privateKeyBase64) else { return nil }
        // Expect 32-byte Ed25519 seed
        guard skData.count == 32 else { return nil }
        if let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: skData) {
            let pubData = privateKey.publicKey.rawRepresentation
            return pubData.map { String(format: "%02x", $0) }.joined()
        }
        return nil
    }
}


