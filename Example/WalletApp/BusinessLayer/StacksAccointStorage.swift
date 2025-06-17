import Foundation
import ReownWalletKit

class StacksAccountStorage {
    enum Errors: Error {
        case invalidWallet
    }
    
    static var storageKey = "stacks_wallet"
    private let chainId: Blockchain = Blockchain("stacks:1")!
    
    func getAddress() throws -> String? {
        guard let wallet = getWallet() else { return nil }
        return try stacksGetAddress(wallet: wallet, version: "mainnet-p2pkh")
    }
    
    func getCaip10Account() throws -> ReownWalletKit.Account? {
        guard let address = try getAddress() else { return nil }
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
