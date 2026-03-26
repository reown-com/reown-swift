import SwiftUI

/// Maps chain IDs (CAIP-2 format) to asset catalog image names.
/// Used by NetworkSelectorView, ChainIconsView, and connection detail screens.
enum ChainIconProvider {
    /// Returns the asset catalog image name for a given CAIP-2 chain ID (e.g. "eip155:1").
    static func imageName(for chainId: String) -> String? {
        chainData(for: chainId)?.imageName
    }

    /// Returns a human-readable chain name for a given CAIP-2 chain ID (e.g. "eip155:1" → "Ethereum").
    static func chainName(for chainId: String) -> String? {
        chainData(for: chainId)?.name
    }

    private static func chainData(for chainId: String) -> (imageName: String, name: String)? {
        let parts = chainId.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        let ns = parts[0].lowercased()
        let ref = String(parts[1])

        switch ns {
        case "eip155":
            switch ref {
            case "1": return ("Ethereum", "Ethereum")
            case "137": return ("Polygon", "Polygon")
            case "10": return ("Optimism", "Optimism")
            case "42161": return ("Arbitrum", "Arbitrum")
            case "56": return ("BNBChain", "BNB Chain")
            case "43114": return ("Avalanche", "Avalanche")
            case "100": return ("Gnosis", "Gnosis")
            case "42220": return ("Celo", "Celo")
            case "8453": return ("Base", "Base")
            case "324": return ("zkSync", "zkSync")
            case "5": return ("Goerli", "Goerli")
            case "11155111": return ("Sepolia", "Sepolia")
            case "143": return ("Monad", "Monad")
            case "36900": return ("ADI", "ADI")
            default: return nil
            }
        case "bip122": return ("Bitcoin", "Bitcoin")
        case "cosmos": return ("Cosmos", "Cosmos")
        case "kadena": return ("Kadena", "Kadena")
        case "polkadot": return ("Polkadot", "Polkadot")
        case "solana": return ("Solana", "Solana")
        case "stacks": return ("Stacks", "Stacks")
        case "sui": return ("Sui", "Sui")
        case "ton":
            switch ref {
            case "-239": return ("TON", "TON")
            case "-3": return ("TON", "TON Testnet")
            default: return ("TON", "TON")
            }
        case "tron":
            switch ref {
            case "0x2b6653dc": return ("Tron", "Tron")
            case "0xcd8690dc": return ("Tron", "Tron Testnet")
            default: return ("Tron", "Tron")
            }
        default: return nil
        }
    }
}
