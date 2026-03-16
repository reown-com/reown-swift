import Foundation
import HDWalletKit

final class WalletGenerationService {

    private let accountStorage: AccountStorage
    private let solanaAccountStorage: SolanaAccountStorage
    private let stacksAccountStorage: StacksAccountStorage
    private let suiAccountStorage: SuiAccountStorage
    private let tonAccountStorage: TonAccountStorage
    private let tronAccountStorage: TronAccountStorage

    init(
        accountStorage: AccountStorage,
        solanaAccountStorage: SolanaAccountStorage = SolanaAccountStorage(),
        stacksAccountStorage: StacksAccountStorage = StacksAccountStorage(),
        suiAccountStorage: SuiAccountStorage = SuiAccountStorage(),
        tonAccountStorage: TonAccountStorage = TonAccountStorage(),
        tronAccountStorage: TronAccountStorage = TronAccountStorage()
    ) {
        self.accountStorage = accountStorage
        self.solanaAccountStorage = solanaAccountStorage
        self.stacksAccountStorage = stacksAccountStorage
        self.suiAccountStorage = suiAccountStorage
        self.tonAccountStorage = tonAccountStorage
        self.tronAccountStorage = tronAccountStorage
    }

    /// Generates all wallets for every supported chain and saves them.
    /// Returns the EVM ImportAccount.
    @discardableResult
    func generateAllWallets() -> ImportAccount {
        let evmAccount = ImportAccount.new()
        accountStorage.importAccount = evmAccount
        solanaAccountStorage.generateAndSaveAccount()
        stacksAccountStorage.generateAndSaveWallet()
        suiAccountStorage.generateAndSaveKeypair()
        tonAccountStorage.generateAndSaveKeypair()
        tronAccountStorage.generateAndSaveKeypair()
        return evmAccount
    }

    // MARK: - Per-chain import (replaces existing wallet)

    func importEVMPrivateKey(_ privateKey: String) -> Bool {
        guard let account = ImportAccount(input: privateKey) else { return false }
        accountStorage.importAccount = account
        return true
    }

    func importEVMMnemonic(_ mnemonic: String) -> Bool {
        let trimmed = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.components(separatedBy: " ").count
        guard [12, 15, 18, 21, 24].contains(wordCount) else { return false }

        let seed = Mnemonic.createSeed(mnemonic: trimmed)
        let masterKey = PrivateKey(seed: seed, coin: .ethereum)
        let derived = masterKey
            .derived(at: .hardened(44))
            .derived(at: .hardened(60))
            .derived(at: .hardened(0))
            .derived(at: .notHardened(0))
            .derived(at: .notHardened(0))
        let hexKey = derived.raw.toHexString()
        return importEVMPrivateKey(hexKey)
    }

    func importSolanaPrivateKey(_ privateKey: String) -> Bool {
        return solanaAccountStorage.savePrivateKey(privateKey) != nil
    }

    func importSuiKeypair(_ keypair: String) -> Bool {
        return suiAccountStorage.savePrivateKey(keypair)
    }

    func importTonPrivateKey(_ privateKeyBase64: String) -> Bool {
        return tonAccountStorage.savePrivateKey(privateKeyBase64)
    }

    func importTronPrivateKey(_ privateKeyHex: String) -> Bool {
        return tronAccountStorage.savePrivateKey(privateKeyHex)
    }

    func importStacksMnemonic(_ mnemonic: String) -> Bool {
        let trimmed = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        stacksAccountStorage.saveWallet(wallet: trimmed)
        return true
    }
}
