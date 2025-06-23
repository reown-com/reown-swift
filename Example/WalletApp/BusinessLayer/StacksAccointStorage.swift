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
    static let chainId: Blockchain = Blockchain("stacks:2147483648")!
    
    /*:
     
     "mainnet-p2pkh" => Version::MainnetP2PKH,
     "mainnet-p2sh" => Version::MainnetP2SH,
     "testnet-p2pkh" => Version::TestnetP2PKH,
     "testnet-p2sh" => Version::TestnetP2SH,
     
     p2sh must be used for sign message in message body
     faucet: https://platform.hiro.so/faucet
     */
    func getAddress() throws -> String? {
        guard let wallet = getWallet() else { return nil }
        return try stacksGetAddress(wallet: wallet, version: "testnet-p2pkh")
    }
    
    func getCaip10Account() throws -> ReownWalletKit.Account? {
        guard let address = try getAddress() else { return nil }
        return Account(blockchain: Self.chainId, address: address)!
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
