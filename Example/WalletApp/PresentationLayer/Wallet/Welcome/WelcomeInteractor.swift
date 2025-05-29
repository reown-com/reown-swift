final class WelcomeInteractor {

    private let accountStorage: AccountStorage
    private let solanaAccountStorage: SolanaAccountStorage
    
    init(accountStorage: AccountStorage, solanaAccountStorage: SolanaAccountStorage = SolanaAccountStorage()) {
        self.accountStorage = accountStorage
        self.solanaAccountStorage = solanaAccountStorage
    }

    func save(importAccount: ImportAccount) {
        accountStorage.importAccount = importAccount
    }
    
    func saveSolanaPrivateKey(_ privateKey: String) {
        solanaAccountStorage.savePrivateKey(privateKey)
    }
}
