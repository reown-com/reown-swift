import Foundation

/// Utility for detecting WalletConnect Pay payment links
///
/// Detects payment links by checking for:
/// - `pay.` hosts (pay.walletconnect.com, staging.pay.walletconnect.com, pay.wct.me)
/// - `pay=` parameter (WC URI pay param)
/// - `pay_` prefix (bare payment IDs)
/// - URL-encoded versions: `pay%2e`, `pay%3d`, `pay%5f`
public enum PaymentLinkDetector {
    /// Check if a string is a WalletConnect Pay payment link
    /// - Parameter string: The string to check (URL, WC URI, or bare payment ID)
    /// - Returns: `true` if the string appears to be a payment link
    public static func isPaymentLink(_ string: String) -> Bool {
        let lower = string.lowercased()
        return lower.contains("pay.") ||
               lower.contains("pay=") ||
               lower.contains("pay_") ||
               lower.contains("pay%2e") ||  // encoded "pay."
               lower.contains("pay%3d") ||  // encoded "pay="
               lower.contains("pay%5f")     // encoded "pay_"
    }
}
