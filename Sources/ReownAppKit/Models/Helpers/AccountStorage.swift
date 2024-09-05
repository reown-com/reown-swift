import Foundation

class AccountStorage {
    enum Keys: String {
        case storeAccount
    }
    
    static func read(defaults: UserDefaults = .standard) -> W3MAccount? {
        guard
            let data = defaults.data(forKey: Keys.storeAccount.rawValue),
            let account = try? JSONDecoder().decode(W3MAccount.self, from: data)
        else {
            return nil
        }
        
        return account
    }
    
    static func save(defaults: UserDefaults = .standard, _ account: W3MAccount?) {
        guard let accountData = try? JSONEncoder().encode(account) else { return }
        
        defaults.set(accountData, forKey: Keys.storeAccount.rawValue)
    }
    
    static func clear(defaults: UserDefaults = .standard) {
        defaults.set(nil, forKey: Keys.storeAccount.rawValue)
    }
}
