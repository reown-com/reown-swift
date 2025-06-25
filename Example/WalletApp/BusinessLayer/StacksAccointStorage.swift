import Foundation
import ReownWalletKit

class StacksAccountStorage {
    enum Errors: Error {
        case invalidWallet
    }
    
    static let storageKey = "stacks_wallet"
    
    /*:
    # Stacks mainnet
    stacks:1

    # Stacks testnet
    stacks:2147483648
    */
    static let mainnetChainId: Blockchain = Blockchain("stacks:1")!
    static let testnetChainId: Blockchain = Blockchain("stacks:2147483648")!
    
    /*:
     
     "mainnet-p2pkh" => Version::MainnetP2PKH,
     "mainnet-p2sh" => Version::MainnetP2SH,
     "testnet-p2pkh" => Version::TestnetP2PKH,
     "testnet-p2sh" => Version::TestnetP2SH,
     
     p2sh must be used for sign message in message body
     faucet: https://platform.hiro.so/faucet
     */
    func getMainnetAddress() throws -> String? {
        guard let wallet = getWallet() else { return nil }
        return try stacksGetAddress(wallet: wallet, version: "mainnet-p2pkh")
    }
    
    func getTestnetAddress() throws -> String? {
        guard let wallet = getWallet() else { return nil }
        return try stacksGetAddress(wallet: wallet, version: "testnet-p2pkh")
    }
    
    func getAddress(for chainId: Blockchain) throws -> String? {
        switch chainId.absoluteString {
        case "stacks:1":
            return try getMainnetAddress()
        case "stacks:2147483648":
            return try getTestnetAddress()
        default:
            return nil
        }
    }
    
    func getMainnetCaip10Account() throws -> ReownWalletKit.Account? {
        guard let address = try getMainnetAddress() else { return nil }
        return Account(blockchain: Self.mainnetChainId, address: address)!
    }
    
    func getTestnetCaip10Account() throws -> ReownWalletKit.Account? {
        guard let address = try getTestnetAddress() else { return nil }
        return Account(blockchain: Self.testnetChainId, address: address)!
    }
    
    func getCaip10Account(for chainId: Blockchain) throws -> ReownWalletKit.Account? {
        guard let address = try getAddress(for: chainId) else { return nil }
        return Account(blockchain: chainId, address: address)!
    }
    
    func saveWallet(wallet: String) {
        UserDefaults.standard.set(wallet, forKey: Self.storageKey)
    }
    
    func getWallet() -> String? {
        return UserDefaults.standard.string(forKey: Self.storageKey)
    }
    
    @discardableResult
    func generateAndSaveWallet() -> String? {
        let mnemonic = stacksGenerateWallet()
        saveWallet(wallet: mnemonic)
        return mnemonic
    }
}
