import Foundation

// MARK: - Pay API Configuration
// Base URL for WalletConnect Pay API
enum PayAPIConfig {
    static let baseURL = "https://api.pay.walletconnect.com"
}

// MARK: - Mock Data Models
// These types will be replaced with types generated from pay client via uniffi

struct PaymentAsset: Identifiable, Equatable {
    let id: String
    let assetName: String
    let assetSymbol: String
    let decimals: Int
    let iconUrl: String
    let networkName: String
    let balance: Double
    let price: Double // Price per unit in USD
    
    var formattedBalance: String {
        String(format: "%.2f %@", balance, assetSymbol)
    }
    
    var formattedPrice: String {
        String(format: "$%.2f", price * balance)
    }
}

struct PaymentNetwork: Identifiable, Equatable {
    let id: String
    let name: String
    let iconUrl: String
    let chainId: String
}

struct PaymentMerchant: Equatable {
    let name: String
    let iconUrl: String
    let isVerified: Bool
}

struct PaymentOptions: Equatable {
    let merchant: PaymentMerchant
    let amount: Double
    let currency: String
    let requiresInformationCapture: Bool
    let requiredFields: [RequiredField]
    let availableAssets: [PaymentAsset]
    let availableNetworks: [PaymentNetwork]
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

enum RequiredField: String, CaseIterable {
    case firstName
    case lastName
    case dateOfBirth
}

struct UserInformation {
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date?
}

// MARK: - Pay Service Protocol
// This protocol defines the interface that will be implemented by the real pay client

protocol PayServiceProtocol {
    func getPaymentOptions(paymentId: String) async throws -> PaymentOptions
    func submitUserInformation(_ info: UserInformation, paymentId: String) async throws
    func executePayment(paymentId: String, assetId: String, networkId: String) async throws -> String
}

// MARK: - Mock Pay Service
// This implementation provides mock data for development

final class MockPayService: PayServiceProtocol {
    
    static let shared = MockPayService()
    
    private init() {}
    
    func getPaymentOptions(paymentId: String) async throws -> PaymentOptions {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return PaymentOptions(
            merchant: PaymentMerchant(
                name: "Hublot",
                iconUrl: "https://example.com/hublot-icon.png",
                isVerified: true
            ),
            amount: 32900,
            currency: "USD",
            requiresInformationCapture: true,
            requiredFields: [.firstName, .lastName],
            availableAssets: [
                PaymentAsset(
                    id: "usdc-base",
                    assetName: "USD Coin",
                    assetSymbol: "USDC",
                    decimals: 6,
                    iconUrl: "https://cryptologos.cc/logos/usd-coin-usdc-logo.png",
                    networkName: "Base",
                    balance: 35000,
                    price: 1.0
                ),
                PaymentAsset(
                    id: "usdt-base",
                    assetName: "Tether USD",
                    assetSymbol: "USDT",
                    decimals: 6,
                    iconUrl: "https://cryptologos.cc/logos/tether-usdt-logo.png",
                    networkName: "Base",
                    balance: 15000,
                    price: 1.0
                ),
                PaymentAsset(
                    id: "eth-base",
                    assetName: "Ethereum",
                    assetSymbol: "ETH",
                    decimals: 18,
                    iconUrl: "https://cryptologos.cc/logos/ethereum-eth-logo.png",
                    networkName: "Base",
                    balance: 10.5,
                    price: 3500
                )
            ],
            availableNetworks: [
                PaymentNetwork(
                    id: "base",
                    name: "Base",
                    iconUrl: "https://raw.githubusercontent.com/base-org/brand-kit/main/logo/symbol/Base_Symbol_Blue.png",
                    chainId: "8453"
                ),
                PaymentNetwork(
                    id: "optimism",
                    name: "Optimism",
                    iconUrl: "https://cryptologos.cc/logos/optimism-ethereum-op-logo.png",
                    chainId: "10"
                ),
                PaymentNetwork(
                    id: "arbitrum",
                    name: "Arbitrum",
                    iconUrl: "https://cryptologos.cc/logos/arbitrum-arb-logo.png",
                    chainId: "42161"
                )
            ]
        )
    }
    
    func submitUserInformation(_ info: UserInformation, paymentId: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Submitted user info: \(info.firstName) \(info.lastName)")
    }
    
    func executePayment(paymentId: String, assetId: String, networkId: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "0x1234567890abcdef1234567890abcdef12345678"
    }
}
