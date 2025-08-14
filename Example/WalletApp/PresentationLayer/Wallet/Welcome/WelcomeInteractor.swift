final class WelcomeInteractor {

    private let accountStorage: AccountStorage
    private let solanaAccountStorage: SolanaAccountStorage
    private let stacksAccountStorage: StacksAccountStorage
    private let suiAccountStorage: SuiAccountStorage
    
    init(accountStorage: AccountStorage, solanaAccountStorage: SolanaAccountStorage = SolanaAccountStorage(), stacksAccountStorage: StacksAccountStorage = StacksAccountStorage(), suiAccountStorage: SuiAccountStorage = SuiAccountStorage()) {
        self.accountStorage = accountStorage
        self.solanaAccountStorage = solanaAccountStorage
        self.stacksAccountStorage = stacksAccountStorage
        self.suiAccountStorage = suiAccountStorage
    }

    func save(importAccount: ImportAccount) {
        accountStorage.importAccount = importAccount
    }
    
    func saveSolanaPrivateKey(_ privateKey: String) {
        solanaAccountStorage.savePrivateKey(privateKey)
    }
    
    func saveStacksWallet(_ wallet: String) {
        stacksAccountStorage.saveWallet(wallet: wallet)
    }
    
    func generateAndSaveStacksWallet() -> String? {
        return stacksAccountStorage.generateAndSaveWallet()
    }

    func saveSuiPrivateKey(_ privateKey: String) {
        suiAccountStorage.savePrivateKey(privateKey)
    }
    
    func generateSuiAccount() {
        suiAccountStorage.generateAndSaveKeypair()
    }
}
