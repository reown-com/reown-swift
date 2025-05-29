import Foundation
import ReownWalletKit

// Define the types that will be used with Sui methods
typealias SuiKeyPair = String
typealias PublicKey = String

class SuiAccountStorage {
    enum Errors: Error {
        case invalidPrivateKey
        case keypairGenerationFailed
        case publicKeyExtractionFailed
        case addressGenerationFailed
    }
    
    static var storageKey = "sui_privateKey"
    private let chainId: Blockchain = Blockchain("sui:mainnet")!

    /// Generates a new Sui keypair and saves it to UserDefaults
    @discardableResult
    func generateAndSaveKeypair() -> SuiKeyPair? {
        do {
            let keypair = try generateKeypair()
            UserDefaults.standard.set(keypair, forKey: Self.storageKey)
            return keypair
        } catch {
            return nil
        }
    }

    /// Saves a private key to UserDefaults
    @discardableResult
    func savePrivateKey(_ privateKey: String) -> Bool {
        UserDefaults.standard.set(privateKey, forKey: Self.storageKey)
        return true
    }

    /// Returns the stored private key from UserDefaults
    func getPrivateKey() -> String? {
        return UserDefaults.standard.string(forKey: Self.storageKey)
    }

    /// Returns the Sui address for the stored private key
    func getAddress() -> String? {
        guard let privateKey = getPrivateKey() else { return nil }
        
        do {
            let publicKey = try getPublicKey(from: privateKey)
            let address = try getAddress(from: publicKey)
            return address
        } catch {
            return nil
        }
    }

    func getCaip10Account() -> ReownWalletKit.Account? {
        guard let address = getAddress() else { return nil }
        return Account(blockchain: chainId, address: address)!
    }

    /// Generates a new Sui keypair using the provided method
    private func generateKeypair() throws -> SuiKeyPair {
        let keypair = suiGenerateKeypair()
        guard !keypair.isEmpty else {
            throw Errors.keypairGenerationFailed
        }
        return keypair
    }

    /// Extracts the public key from a keypair using the provided method
    private func getPublicKey(from keypair: SuiKeyPair) throws -> PublicKey {
        let publicKey = suiGetPublicKey(keypair: keypair)
        guard !publicKey.isEmpty else {
            throw Errors.publicKeyExtractionFailed
        }
        return publicKey
    }

    /// Gets the Sui address from a public key using the provided method
    private func getAddress(from publicKey: PublicKey) throws -> String {
        let address = suiGetAddress(publicKey: publicKey)
        guard !address.isEmpty else {
            throw Errors.addressGenerationFailed
        }
        return address
    }
}

// MARK: - Sui Methods (to be implemented or imported)
// These methods should be implemented elsewhere or imported from a Sui framework

/// Generates a new Sui keypair
func suiGenerateKeypair() -> SuiKeyPair {
    // This should be implemented to generate a Sui keypair
    // For now, returning a placeholder
    return "placeholder_keypair"
}

/// Extracts the public key from a Sui keypair
func suiGetPublicKey(keypair: SuiKeyPair) -> PublicKey {
    // This should be implemented to extract public key from keypair
    // For now, returning a placeholder
    return "placeholder_public_key"
}

/// Gets the Sui address from a public key
func suiGetAddress(publicKey: PublicKey) -> String {
    // This should be implemented to generate address from public key
    // For now, returning a placeholder
    return "placeholder_address"
} 