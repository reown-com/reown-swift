import Foundation

/// Represents EVM chains where we fetch USDC balances
enum USDCChain: String, CaseIterable, Identifiable {
    case ethereum = "Ethereum"
    case base = "Base"
    case arbitrum = "Arbitrum"
    case polygon = "Polygon"
    case optimism = "Optimism"

    var id: String { rawValue }

    /// Chains that support EURC
    static let eurcChains: [USDCChain] = [.ethereum, .base, .optimism]
    
    /// Chain ID in CAIP-2 format (eip155:chainId)
    var chainId: String {
        switch self {
        case .ethereum:
            return "eip155:1"
        case .base:
            return "eip155:8453"
        case .arbitrum:
            return "eip155:42161"
        case .polygon:
            return "eip155:137"
        case .optimism:
            return "eip155:10"
        }
    }
    
    /// USDC contract address for each chain
    var usdcContractAddress: String {
        switch self {
        case .ethereum:
            return "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        case .base:
            return "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        case .arbitrum:
            return "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
        case .polygon:
            return "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"
        case .optimism:
            return "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85"
        }
    }
    
    /// Icon/color for visual distinction
    var iconColor: String {
        switch self {
        case .ethereum:
            return "🔵"
        case .base:
            return "🔷"
        case .arbitrum:
            return "🟠"
        case .polygon:
            return "🟣"
        case .optimism:
            return "🔴"
        }
    }
}



