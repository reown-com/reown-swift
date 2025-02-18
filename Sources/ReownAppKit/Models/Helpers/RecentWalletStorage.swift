import Foundation

class RecentWalletsStorage {
    
    static func loadRecentWallets(defaults: UserDefaults = .standard) -> [Wallet] {
        guard
            let data = defaults.data(forKey: "recentWallets"),
            let wallets = try? JSONDecoder().decode([Wallet].self, from: data)
        else {
            return []
        }
        
        return wallets
    }
    
    static func saveRecentWallets(defaults: UserDefaults = .standard, _ wallets: [Wallet])  {
        
        let subset = Array(
            wallets
                .filter {
                    $0.lastTimeUsed != nil
                }
                .sorted(by: { lhs, rhs in
                    lhs.lastTimeUsed! > rhs.lastTimeUsed!
                })
        )
        
        var uniqueValues: [Wallet] = []
        subset.forEach { item in
            guard !uniqueValues.contains(where: { wallet in
                item.id == wallet.id
            }) else { return }
            uniqueValues.append(item)
        }
        
        guard
            let walletsData = try? JSONEncoder().encode(uniqueValues)
        else {
            return
        }
        
        defaults.set(walletsData, forKey: "recentWallets")
    }
}
