import Foundation
import SolanaSwift
import TweetNacl
import ReownWalletKit

class SolanaAccountStorage {
    enum Errors: Error {
        case invalidPrivateKey
    }
    
    static var storageKey = "solana_privateKey"
    private let chainId: Blockchain = Blockchain("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")!

    /// Saves a private key to UserDefaults and returns the created account
    @discardableResult
    func savePrivateKey(_ privateKey: String) -> SolanaSwift.Account? {
        do {
            let account = try createAccount(from: privateKey)
            UserDefaults.standard.set(privateKey, forKey: Self.storageKey)
            return account
        } catch {
            return nil
        }
    }

    /// Returns the stored private key from UserDefaults
    func getPrivateKey() -> String? {
        return UserDefaults.standard.string(forKey: Self.storageKey)
    }

    /// Generates a new account and stores its private key
    @discardableResult
    func generateAndSaveAccount() -> SolanaSwift.Account? {
        let seed = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        guard
            let keypair = try? NaclSign.KeyPair.keyPair(fromSeed: seed),
            let account = try? Account(secretKey: Data(keypair.secretKey))
        else { return nil }

        UserDefaults.standard.set(Base58.encode(Array(account.secretKey)), forKey: Self.storageKey)
        return account
    }

    /// Returns the Solana address for the stored private key
    func getAddress() -> String? {
        guard let privateKey = getPrivateKey() else { return nil }
        
        do {
            let account = try createAccount(from: privateKey)
            return account.publicKey.base58EncodedString
        } catch {
            return nil
        }
    }

    func getCaip10Account() -> ReownWalletKit.Account? {
        guard let address = getAddress() else { return nil }
        return Account(blockchain: chainId, address: address)!
    }

    /// Creates a Solana account from a private key
    func createAccount(from privateKey: String) throws -> SolanaSwift.Account {
        let secretKey = Data(SolanaSwift.Base58.decode(privateKey))

        do {
            return try Account(secretKey: secretKey)
        } catch {
            throw Errors.invalidPrivateKey
        }
    }
}
