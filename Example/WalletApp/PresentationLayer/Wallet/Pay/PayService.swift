import Foundation
import WalletConnectPay

// MARK: - Helper Extensions

extension PaymentInfo {
    /// Formatted amount string for display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = Int(amount.display.decimals)
        if let value = Double(amount.value) {
            let displayValue = value / pow(10, Double(amount.display.decimals))
            let formattedNumber = formatter.string(from: NSNumber(value: displayValue)) ?? "\(displayValue)"
            return "\(formattedNumber) \(amount.display.assetSymbol)"
        }
        return "\(amount.value) \(amount.display.assetSymbol)"
    }
}

extension PaymentOption {
    /// Formatted amount string for display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = Int(amount.display.decimals)
        if let value = Double(amount.value) {
            let displayValue = value / pow(10, Double(amount.display.decimals))
            let formattedNumber = formatter.string(from: NSNumber(value: displayValue)) ?? "\(displayValue)"
            return "\(formattedNumber) \(amount.display.assetSymbol)"
        }
        return "\(amount.value) \(amount.display.assetSymbol)"
    }
}
