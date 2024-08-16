import Foundation

class RecentWalletsStorage {
    
    static func loadRecentWallets(defaults: UserDefaults = .standard) -> [Wallet] {
        guard
            let data = defaults.data(forKey: "recentWallets"),
            let wallets = try? JSONDecoder().decode([Wallet].self, from: data)
        else {
            return []
        }
        
        return wallets.filter { wallet in
            guard let lastTimeUsed = wallet.lastTimeUsed else {
                assertionFailure("Shouldn't happen we stored wallet without `lastTimeUsed`")
                return false
            }
            
            // Consider Recent only for 3 days
            return abs(lastTimeUsed.timeIntervalSinceNow) < (24 * 60 * 60 * 3)
        }
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
                .prefix(2)
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
