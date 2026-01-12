import Foundation
import WalletConnectPay

// MARK: - Helper Extensions

extension PaymentInfo {
    /// Formatted amount string for display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = amount.unit
        formatter.currencySymbol = "$"
        if let value = Double(amount.value) {
            let displayValue = value / pow(10, Double(amount.display.decimals))
            return formatter.string(from: NSNumber(value: displayValue)) ?? "$\(amount.value)"
        }
        return "$\(amount.display.assetSymbol) \(amount.value)"
    }
}

extension PaymentOption {
    /// Formatted amount string for display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = amount.unit
        formatter.currencySymbol = "$"
        if let value = Double(amount.value) {
            let displayValue = value / pow(10, Double(amount.display.decimals))
            return formatter.string(from: NSNumber(value: displayValue)) ?? "$\(amount.value)"
        }
        return "\(amount.display.assetSymbol) \(amount.value)"
    }
}
