final class WelcomeInteractor {

    private let accountStorage: AccountStorage
    private let solanaAccountStorage: SolanaAccountStorage
    private let suiAccountStorage: SuiAccountStorage
    
    init(accountStorage: AccountStorage, solanaAccountStorage: SolanaAccountStorage = SolanaAccountStorage(), suiAccountStorage: SuiAccountStorage = SuiAccountStorage()) {
        self.accountStorage = accountStorage
        self.solanaAccountStorage = solanaAccountStorage
        self.suiAccountStorage = suiAccountStorage
    }

    func save(importAccount: ImportAccount) {
        accountStorage.importAccount = importAccount
    }
    
    func saveSolanaPrivateKey(_ privateKey: String) {
        solanaAccountStorage.savePrivateKey(privateKey)
    }
    
    func saveSuiPrivateKey(_ privateKey: String) {
        suiAccountStorage.savePrivateKey(privateKey)
    }
    
    func generateSuiAccount() {
        suiAccountStorage.generateAndSaveKeypair()
    }
}
