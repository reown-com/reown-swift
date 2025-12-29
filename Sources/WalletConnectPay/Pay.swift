import Foundation
@_exported import YttriumWrapper

/// WalletConnectPay - Payment SDK for WalletConnect
///
/// A singleton wrapper around the Yttrium WalletConnectPay client that provides
/// payment functionality for wallet applications.
///
/// ## Usage
/// ```swift
/// // Configure the Pay client
/// WalletConnectPay.configure(projectId: "your-project-id")
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
/// // Sign required actions and confirm payment
/// let results = signActions(actions) // Your signing implementation
/// let response = try await WalletConnectPay.instance.confirmPayment(
///     paymentId: paymentId,
///     optionId: optionId,
///     results: results
/// )
/// ```
public class WalletConnectPay {
    
    /// Shared WalletConnectPay client instance
    /// - Important: Call `WalletConnectPay.configure(projectId:)` before accessing this property
    public static var instance: PayClient = {
        guard let config = WalletConnectPay.config else {
            fatalError("Error - you must call WalletConnectPay.configure(projectId:) before accessing the shared instance.")
        }
        return PayClient(config: config)
    }()
    
    private static var config: SdkConfig?
    
    private init() {}
    
    /// Configure the WalletConnectPay client
    /// - Parameters:
    ///   - projectId: Your WalletConnect project ID
    ///   - baseUrl: Optional custom base URL (defaults to production)
    public static func configure(
        projectId: String,
        baseUrl: String = "https://rpc.walletconnect.org"
    ) {
        WalletConnectPay.config = SdkConfig(
            baseUrl: baseUrl,
            apiKey: projectId,
            sdkName: "reown-swift",
            sdkVersion: "1.0.0",
            sdkPlatform: "ios"
        )
    }
}

// Typealias for the Yttrium WalletConnectPay to avoid naming conflict with our wrapper
public typealias YttriumPayClient = Yttrium.WalletConnectPay

/// PayClient - Wrapper around Yttrium WalletConnectPay
///
/// Provides typed Swift methods for interacting with the WalletConnect Pay API.
public class PayClient {
    
    private let client: YttriumPayClient
    
    init(config: SdkConfig) {
        self.client = YttriumPayClient(config: config)
    }
    
    // MARK: - Public Methods
    
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
    /// Returns the list of actions that need to be performed to complete the payment.
    /// Actions can be:
    /// - `walletRpc`: Requires wallet to sign a message (e.g., eth_signTypedData_v4 for permits)
    /// - `build`: Requires building and signing a transaction
    ///
    /// - Parameters:
    ///   - paymentId: The payment ID from payment options
    ///   - optionId: The selected payment option ID
    /// - Returns: Array of required actions to perform
    /// - Throws: `GetPaymentRequestError` if the request fails
    public func getRequiredPaymentActions(
        paymentId: String,
        optionId: String
    ) async throws -> [RequiredAction] {
        try await client.getRequiredPaymentActions(
            paymentId: paymentId,
            optionId: optionId
        )
    }
    
    /// Confirm a payment after signing required actions
    ///
    /// Submits the signed actions to complete the payment. The method polls for
    /// the final payment status if the initial response is not final.
    ///
    /// Before calling this method:
    /// 1. Call `getRequiredPaymentActions` to get the actions
    /// 2. For each `walletRpc` action with method `eth_signTypedData_v4`, sign the typed data
    /// 3. Collect all signatures as `SignatureResult` array
    ///
    /// - Parameters:
    ///   - paymentId: The payment ID
    ///   - optionId: The selected payment option ID
    ///   - results: Array of signature results from signing the required actions
    ///   - maxPollMs: Optional max polling time in milliseconds (default: 60000)
    /// - Returns: Confirmation response with final payment status
    /// - Throws: `ConfirmPaymentError` if confirmation fails
    public func confirmPayment(
        paymentId: String,
        optionId: String,
        results: [SignatureResult],
        maxPollMs: Int64? = nil
    ) async throws -> ConfirmPaymentResultResponse {
        try await client.confirmPayment(
            paymentId: paymentId,
            optionId: optionId,
            results: results,
            maxPollMs: maxPollMs
        )
    }
}
