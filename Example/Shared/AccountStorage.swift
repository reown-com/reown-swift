import Foundation

final class AccountStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var importAccount: ImportAccount? {
        get {
            guard let value = UserDefaults.standard.string(forKey: "account") else {
                return nil
            }
            guard let account = ImportAccount(input: value) else {
                // Migration
                self.importAccount = nil
                return nil
            }
            return account
        }
        set {
            UserDefaults.standard.set(newValue?.storageId, forKey: "account")
        }
    }

    /// True once the user imports a wallet via the Settings UI. Used to prevent
    /// `TEST_WALLET_PRIVATE_KEY` from overwriting a manually-imported wallet on subsequent launches.
    var userImportedWallet: Bool {
        get { UserDefaults.standard.bool(forKey: "userImportedWallet") }
        set { UserDefaults.standard.set(newValue, forKey: "userImportedWallet") }
    }
}
