import Foundation
import WalletConnectPay

/// Pay namespace for WalletKit
///
/// Provides payment functionality through `WalletKit.instance.Pay.*`
///
/// ## Usage
/// ```swift
/// // Get payment options for a payment link
/// let options = try await WalletKit.instance.Pay.getPaymentOptions(
///     paymentLink: "https://pay.walletconnect.com/?pid=pay_123",
///     accounts: ["eip155:1:0x..."]
/// )
///
/// // Get required actions for the selected option
/// let actions = try await WalletKit.instance.Pay.getRequiredPaymentActions(
///     paymentId: options.paymentId,
///     optionId: selectedOption.id
/// )
///
/// // Sign actions and confirm payment
/// let result = try await WalletKit.instance.Pay.confirmPayment(
///     paymentId: paymentId,
///     optionId: optionId,
///     signatures: signatures
/// )
/// ```
public class PayNamespace {

    private let payClient: PayClient

    init(payClient: PayClient) {
        self.payClient = payClient
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
        try await payClient.getPaymentOptions(
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
    /// - Parameters:
    ///   - paymentId: The payment ID from payment options
    ///   - optionId: The selected payment option ID
    /// - Returns: Array of wallet RPC actions to sign
    /// - Throws: `GetPaymentRequestError` if the request fails
    public func getRequiredPaymentActions(
        paymentId: String,
        optionId: String
    ) async throws -> [Action] {
        try await payClient.getRequiredPaymentActions(
            paymentId: paymentId,
            optionId: optionId
        )
    }

    /// Confirm a payment with wallet RPC signatures
    ///
    /// Submits the signed actions to complete the payment. The method polls for
    /// the final payment status if the initial response is not final.
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
        try await payClient.confirmPayment(
            paymentId: paymentId,
            optionId: optionId,
            signatures: signatures,
            collectedData: collectedData,
            maxPollMs: maxPollMs
        )
    }

    /// Check if a string is a WalletConnect Pay payment link
    /// - Parameter string: The string to check (URL, WC URI, or bare payment ID)
    /// - Returns: `true` if the string appears to be a payment link
    public func isPaymentLink(_ string: String) -> Bool {
        PaymentLinkDetector.isPaymentLink(string)
    }
}
