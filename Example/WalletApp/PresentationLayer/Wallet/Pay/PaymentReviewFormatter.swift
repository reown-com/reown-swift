import Foundation
import WalletConnectPay

/// Centralizes the user-facing strings on the Pay summary / options screens so
/// the views can stay layout-only and tests can assert formatting directly.
/// Mirrors Kotlin PR #385's `PaymentReviewFormatter`.
enum PaymentReviewFormatter {
    private static let usdCurrencyCode = "USD"

    /// Numeric merchant amount in its denominated unit (e.g. 2500.0 for €2500
    /// or $25.00). Returns `nil` if the raw value can't be parsed.
    static func merchantAmount(_ info: PaymentInfo) -> Double? {
        guard let raw = Double(info.amount.value) else { return nil }
        return raw / pow(10, Double(info.amount.display.decimals))
    }

    /// Short fiat string used in the option-row suffix ("+$0.012") and the
    /// explainer ("Gas fee : $0.012"). Falls back to the native amount if the
    /// fiat lookup is missing.
    ///
    /// Sub-cent fees collapse to "<$0.01" so we never render a misleading
    /// "$0.00" while still indicating that some non-zero fee applies.
    static func formatFee(_ estimate: FeeEstimate) -> String {
        if let fiat = estimate.fiatAmount, fiat.isFinite, fiat > 0 {
            if fiat < 0.01 {
                return "<" + formatFiat(0.01, currency: estimate.fiatCurrency)
            }
            return formatFiat(fiat, currency: estimate.fiatCurrency)
        }
        return formatNative(estimate.nativeAmount, symbol: estimate.nativeSymbol)
    }

    /// Inline suffix shown to the right of a token amount on rows that carry a
    /// one-time approval fee, e.g. "+$0.012". For sub-cent fees this renders
    /// without the "+" prefix since the formatted value already starts with "<".
    static func feeRowSuffix(_ estimate: FeeEstimate) -> String {
        let formatted = formatFee(estimate)
        return formatted.hasPrefix("<") ? formatted : "+" + formatted
    }

    /// Pay button label, e.g. "Pay $2500" or "Pay $2500.01 (incl. gas fee)".
    static func payButtonLabel(merchantInfo: PaymentInfo, fee: FeeEstimate?) -> String {
        guard let total = merchantAmount(merchantInfo) else {
            return "Pay \(merchantInfo.formattedAmount)"
        }
        let merchantCurrency = merchantInfo.amount.display.assetSymbol
        guard let fee, let fiat = fee.fiatAmount, fiat.isFinite, fiat > 0,
              fee.fiatCurrency.caseInsensitiveCompare(merchantCurrency) == .orderedSame else {
            return "Pay " + formatFiat(total, currency: merchantCurrency)
        }
        let combined = total + fiat
        return "Pay " + formatFiat(combined, currency: merchantCurrency) + " (incl. gas fee)"
    }

    /// Explainer screen title — e.g. "Why does USDT require a gas fee?".
    static func explainerTitle(tokenSymbol: String) -> String {
        "Why does \(tokenSymbol) require a gas fee?"
    }

    /// Explainer body — e.g. "The gas fee covers a one-time setup that lets your wallet pay with USDT. ..."
    static func explainerBody(tokenSymbol: String) -> String {
        "The gas fee covers a one-time setup that lets your wallet pay with \(tokenSymbol). You only pay it once. Future \(tokenSymbol) payments from this wallet skip this step."
    }

    /// "Why does USDT require a gas fee?" — used as the underlined link on the summary screen.
    static func explainerLinkLabel(tokenSymbol: String) -> String {
        "Why does \(tokenSymbol) require a gas fee?"
    }

    // MARK: - Helpers

    private static func formatFiat(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale.current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }

    private static func formatNative(_ amount: Double, symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        let digits = amount >= 0.01 ? 4 : 6
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        let body = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.6f", amount)
        return "~\(body) \(symbol)"
    }
}
