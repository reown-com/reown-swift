import Foundation
@_exported import YttriumWrapper

/// WalletConnectPay - Payment SDK for WalletConnect
///
/// A singleton wrapper around the Yttrium WalletConnectPay client that provides
/// payment functionality for wallet applications.
///
/// ## Usage
/// ```swift
/// // Configure the Pay client (using appId - recommended for wallets)
/// WalletConnectPay.configure(appId: "your-project-id")
///
/// // Or with API key
/// WalletConnectPay.configure(apiKey: "your-pay-api-key")
///
/// // Get payment options
/// let options = try await WalletConnectPay.instance.getPaymentOptions(
///     paymentLink: "https://...",
///     accounts: ["eip155:1:0x..."]
/// )
///
/// // Get required actions for selected option
/// let actions = try await WalletConnectPay.instance.getRequiredPaymentActions(
///     paymentId: options.info?.paymentId,
///     optionId: selectedOption.id
/// )
///
/// // Sign each action and collect signatures
/// var signatures: [String] = []
/// for action in actions {
///     let signature = try await sign(action.walletRpc) // Your signing implementation
///     signatures.append(signature)
/// }
///
/// // Check if user data collection is required (travel rule)
/// var collectedData: [CollectDataFieldResult]? = nil
/// if let collectData = options.collectData {
///     collectedData = collectUserData(collectData.fields) // Your UI implementation
/// }
///
/// // Confirm payment
/// let response = try await WalletConnectPay.instance.confirmPayment(
///     paymentId: paymentId,
///     optionId: optionId,
///     signatures: signatures,
///     collectedData: collectedData
/// )
/// ```
public class WalletConnectPay {

    /// Shared WalletConnectPay client instance
    /// - Important: Call `WalletConnectPay.configure(apiKey:appId:)` before accessing this property
    public static var instance: PayClient = {
        guard let config = WalletConnectPay.config else {
            fatalError("Error - you must call WalletConnectPay.configure(apiKey:appId:) before accessing the shared instance.")
        }
        do {
            return try PayClient(config: config, logging: WalletConnectPay.loggingEnabled)
        } catch {
            fatalError("Error - failed to initialize PayClient: \(error). Ensure at least one of apiKey or appId is provided.")
        }
    }()

    private static var config: SdkConfig?
    private static var loggingEnabled: Bool = false

    private static var packageVersion: String {
        guard let configURL = Bundle.payResourceBundle.url(forResource: "PackageConfig", withExtension: "json") else {
            fatalError("Unable to find PackageConfig.json in the resource bundle")
        }

        do {
            let jsonData = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(PayPackageConfig.self, from: jsonData)
            return config.version
        } catch {
            fatalError("Failed to load and decode PackageConfig.json: \(error)")
        }
    }

    private init() {}
    
    /// Configure the WalletConnectPay client
    /// - Parameters:
    ///   - apiKey: Your WalletConnect Pay API key (optional)
    ///   - appId: Your app identifier, typically your WalletConnect project ID (optional, recommended for wallets)
    ///   - baseUrl: Optional custom base URL (defaults to production Pay API)
    ///   - logging: Enable debug logging (defaults to false)
    /// - Note: At least one of `apiKey` or `appId` must be provided
    public static func configure(
        apiKey: String? = nil,
        appId: String? = nil,
        baseUrl: String = "https://api.pay.walletconnect.com",
        logging: Bool = false
    ) {
        WalletConnectPay.config = SdkConfig(
            baseUrl: baseUrl,
            projectId: appId,
            sdkName: "swift-walletconnect-pay",
            sdkVersion: packageVersion,
            sdkPlatform: "ios",
            bundleId: Bundle.main.bundleIdentifier ?? "unknown",
            apiKey: apiKey,
            appId: appId,
            clientId: nil
        )
        WalletConnectPay.loggingEnabled = logging
    }
}

// Typealias for the Yttrium WalletConnectPay to avoid naming conflict with our wrapper
public typealias YttriumPayClient = YttriumWrapper.WalletConnectPay

/// PayClient - Wrapper around Yttrium WalletConnectPay
///
/// Provides typed Swift methods for interacting with the WalletConnect Pay API.
public final class PayClient: YttriumWrapper.Logger {
    
    private let client: YttriumPayClient
    private let loggingEnabled: Bool
    
    init(config: SdkConfig, logging: Bool) throws {
        self.client = try YttriumPayClient(config: config)
        self.loggingEnabled = logging

        // Register self as logger - this keeps the logger alive as long as PayClient lives
        registerLogger(logger: self)
    }
    
    // MARK: - Logger Protocol
    
    public func log(message: String) {
        guard loggingEnabled else { return }
        print("💳 [WalletConnectPay] \(message)")
    }
    
    /// Get payment options for a payment link
    ///
    /// Fetches available payment options for the given payment link and wallet accounts.
    /// The response includes merchant info and a list of payment options with different
    /// assets and networks.
    ///
    /// - Parameters:
    ///   - paymentLink: The payment link URL (from deep link or QR code)
    ///   - accounts: List of wallet accounts in CAIP-10 format (e.g., "eip155:1:0x...")
    ///   - includePaymentInfo: Whether to include detailed payment info in response
    /// - Returns: Payment options response containing merchant info and available options
    /// - Throws: `GetPaymentOptionsError` if the request fails
    public func getPaymentOptions(
        paymentLink: String,
        accounts: [String],
        includePaymentInfo: Bool = true
    ) async throws -> PaymentOptionsResponse {
        try await client.getPaymentOptions(
            paymentLink: paymentLink,
            accounts: accounts,
            includePaymentInfo: includePaymentInfo
        )
    }
    
    /// Get required payment actions for a selected option
    ///
    /// Returns the list of wallet RPC actions that need to be signed to complete the payment.
    /// Each action contains a `walletRpc` with method `eth_signTypedData_v4` for permit signing.
    ///
    /// Note: User data collection (travel rule) is handled separately via `PaymentOptionsResponse.collectData`
    ///
    /// - Parameters:
    ///   - paymentId: The payment ID from payment options
    ///   - optionId: The selected payment option ID
    /// - Returns: Array of wallet RPC actions to sign
    /// - Throws: `GetPaymentRequestError` if the request fails
    public func getRequiredPaymentActions(
        paymentId: String,
        optionId: String
    ) async throws -> [Action] {
        try await client.getRequiredPaymentActions(
            paymentId: paymentId,
            optionId: optionId
        )
    }
    
    /// Confirm a payment with wallet RPC signatures
    ///
    /// Submits the signed actions to complete the payment. The method polls for
    /// the final payment status if the initial response is not final.
    ///
    /// Before calling this method:
    /// 1. Call `getRequiredPaymentActions` to get the wallet RPC actions
    /// 2. For each action with method `eth_signTypedData_v4`, sign the typed data
    /// 3. Check `PaymentOptionsResponse.collectData` for required user data fields
    ///
    /// - Parameters:
    ///   - paymentId: The payment ID
    ///   - optionId: The selected payment option ID
    ///   - signatures: Array of hex signatures from signing the wallet RPC actions
    ///   - collectedData: Optional array of collected user data fields (for travel rule compliance)
    ///   - maxPollMs: Optional max polling time in milliseconds (default: 60000)
    /// - Returns: Confirmation response with final payment status
    /// - Throws: `ConfirmPaymentError` if confirmation fails
    public func confirmPayment(
        paymentId: String,
        optionId: String,
        signatures: [String],
        collectedData: [CollectDataFieldResult]? = nil,
        maxPollMs: Int64? = nil
    ) async throws -> ConfirmPaymentResultResponse {
        try await client.confirmPayment(
            paymentId: paymentId,
            optionId: optionId,
            signatures: signatures,
            collectedData: collectedData,
            maxPollMs: maxPollMs
        )
    }
}

