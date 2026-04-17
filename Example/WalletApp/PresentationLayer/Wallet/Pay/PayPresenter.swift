import UIKit
import Combine
import ReownWalletKit
import Commons

enum PayFlowStep: Int, CaseIterable {
    case loading = 0
    case options = 1
    case whyInfoRequired = 2
    case webviewDataCollection = 3
    case summary = 4
    case confirming = 5
    case result = 6
}

final class PayPresenter: ObservableObject {
    var dismissAction: (() -> Void)?
    private let importAccount: ImportAccount
    private var disposeBag = Set<AnyCancellable>()

    // Trusted IC WebView domains
    private static let trustedICDomains = [
        "dev.pay.walletconnect.com",
        "staging.pay.walletconnect.com",
        "pay.walletconnect.com"
    ]

    // Auto-pay mode: when true, skips option selection and auto-confirms
    // Used for NFC tap-to-pay (Apple Pay-like UX)
    let autoPayMode: Bool

    // Flow state
    @Published var currentStep: PayFlowStep = .loading
    @Published var showError = false
    @Published var errorMessage = ""

    // Result state
    @Published var resultType: PayResultType = .success
    @Published var loadingMessage: String = "Preparing your payment..."

    // Payment data
    @Published var paymentOptionsResponse: PaymentOptionsResponse?
    @Published var selectedOption: PaymentOption?
    @Published var requiredActions: [Action] = []

    // Payment result info (from confirmPayment response)
    @Published var paymentResultInfo: ConfirmPaymentResultResponse?

    // Payment link from deep link
    private let paymentLink: String

    // Wallet accounts for payment options
    private let accounts: [String]

    /// Convenience accessor for payment info
    var paymentInfo: PaymentInfo? {
        paymentOptionsResponse?.info
    }

    /// Available payment options
    var paymentOptions: [PaymentOption] {
        paymentOptionsResponse?.options ?? []
    }

    /// Convenience accessor for collectData (top-level, applies to all options)
    /// Note: When Yttrium exposes per-option collectData, switch to selectedOption?.collectData
    var collectData: CollectDataAction? {
        paymentOptionsResponse?.collectData
    }

    /// Whether any option requires information capture
    var anyOptionRequiresIC: Bool {
        collectData != nil
    }

    /// Button title for the options screen — "Continue"
    var optionsButtonTitle: String {
        return "Continue"
    }

    init(paymentLink: String, accounts: [String], importAccount: ImportAccount, autoPayMode: Bool = false) {
        self.paymentLink = paymentLink
        self.accounts = accounts
        self.importAccount = importAccount
        self.autoPayMode = autoPayMode
        loadPaymentOptions()
    }

    // MARK: - Public Methods

    func loadPaymentOptions() {
        loadingMessage = "Preparing your payment..."
        currentStep = .loading
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await WalletKit.instance.Pay.getPaymentOptions(
                    paymentLink: paymentLink,
                    accounts: accounts,
                    includePaymentInfo: true
                )
                self.paymentOptionsResponse = response
                print("💳 [Pay] getPaymentOptions response: \(response)")

                if response.options.isEmpty {
                    // No payment options — show insufficient funds result
                    self.resultType = .insufficientFunds
                    self.currentStep = .result
                } else {
                    // Select first option by default
                    self.selectedOption = response.options.first

                    // Auto-pay mode: skip UI and confirm immediately if possible (NFC tap-to-pay)
                    if self.autoPayMode, self.collectData == nil, let option = response.options.first {
                        self.selectedOption = option
                        self.confirmPayment()
                        return
                    }

                    // Auto-skip to summary for single option with no IC
                    if response.options.count == 1 && response.collectData == nil {
                        self.currentStep = .summary
                    } else {
                        self.currentStep = .options
                    }
                }
            } catch {
                self.resultType = Self.detectResultType(from: error)
                self.currentStep = .result
            }
        }
    }

    /// Called from options screen when user taps the primary button
    func continueFromOptions() {
        guard selectedOption != nil else { return }

        if let collectData = collectData,
           let url = collectData.url, !url.isEmpty {
            currentStep = .webviewDataCollection
        } else {
            currentStep = .summary
        }
    }

    /// Called when IC WebView completes successfully
    func onICWebViewComplete() {
        currentStep = .summary
    }

    /// Called when IC WebView encounters an error
    func onICWebViewError(_ error: String) {
        let detectedType = Self.detectErrorType(from: error)
        switch detectedType {
        case .generic:
            errorMessage = "Information capture failed: \(error)"
            showError = true
        default:
            resultType = detectedType
            currentStep = .result
        }
    }

    /// Build IC WebView URL with domain validation, prefill data, and theme
    func buildICWebViewURL() -> URL? {
        guard let baseUrlString = collectData?.url,
              !baseUrlString.isEmpty,
              var components = URLComponents(string: baseUrlString),
              let host = components.host,
              Self.trustedICDomains.contains(host) else {
            print("⚠️ [Pay] Rejected untrusted or invalid IC URL: \(collectData?.url ?? "nil")")
            return nil
        }

        var queryItems = components.queryItems ?? []

        if let prefill = buildPrefillParam(schema: collectData?.schema) {
            if let idx = queryItems.firstIndex(where: { $0.name == "prefill" }) {
                queryItems[idx] = URLQueryItem(name: "prefill", value: prefill)
            } else {
                queryItems.append(URLQueryItem(name: "prefill", value: prefill))
            }
        }

        // Append theme param
        let theme = ThemeManager.shared.isDarkMode ? "dark" : "light"
        queryItems.append(URLQueryItem(name: "theme", value: theme))
        components.queryItems = queryItems

        return components.url
    }

    /// Build Base64-encoded prefill param from schema's required fields.
    /// Parses the JSON Schema to find all required fields (top-level + anyOf)
    /// and only includes fields that have known prefill values.
    private func buildPrefillParam(schema: String?) -> String? {
        guard let schema = schema,
              let schemaData = schema.data(using: .utf8),
              let schemaJson = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
            return nil
        }

        // Collect required fields from top-level "required" array
        var requiredFields = Set<String>()
        if let topRequired = schemaJson["required"] as? [String] {
            requiredFields.formUnion(topRequired)
        }

        // Collect required fields from "anyOf" conditional groups
        if let anyOf = schemaJson["anyOf"] as? [[String: Any]] {
            for group in anyOf {
                if let groupRequired = group["required"] as? [String] {
                    requiredFields.formUnion(groupRequired)
                }
            }
        }

        // Map of field id -> prefill value
        let fieldValues: [String: String] = [
            "fullName": "Test User",
            "dob": "1990-01-15",
            "pobAddress": "New York, NY",
            "pobCountry": "US",
            "porAddress": "New York, NY",
            "porCountry": "US"
        ]

        // Build prefill dict with only required fields
        var prefillData = [String: String]()
        for fieldId in requiredFields {
            if let value = fieldValues[fieldId] {
                prefillData[fieldId] = value
            }
        }

        guard !prefillData.isEmpty,
              let jsonData = try? JSONSerialization.data(withJSONObject: prefillData) else {
            return nil
        }

        return jsonData.base64EncodedString()
    }

    func goBack() {
        switch currentStep {
        case .loading:
            dismiss()
        case .options:
            dismiss()
        case .whyInfoRequired:
            currentStep = .options
        case .webviewDataCollection:
            currentStep = .options
        case .summary:
            // Go back to the IC step that preceded summary
            if let collectData = collectData,
               let url = collectData.url, !url.isEmpty {
                currentStep = .webviewDataCollection
            } else {
                currentStep = .options
            }
        case .confirming, .result:
            // Don't allow back navigation from these states
            break
        }
    }

    func showWhyInfoRequiredScreen() {
        currentStep = .whyInfoRequired
    }

    func selectOption(_ option: PaymentOption) {
        selectedOption = option
    }

    func confirmPayment() {
        guard let option = selectedOption,
              let paymentId = paymentOptionsResponse?.paymentId else {
            errorMessage = "Please select a payment option"
            showError = true
            return
        }

        // Switch to confirming state
        loadingMessage = "Processing your payment..."
        currentStep = .confirming

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // 1. Get required actions for the selected option
                let actions = try await WalletKit.instance.Pay.getRequiredPaymentActions(
                    paymentId: paymentId,
                    optionId: option.id
                )
                self.requiredActions = actions

                // 2. Sign all wallet RPC actions
                var signatures: [String] = []
                let ethSigner = ETHSigner(importAccount: importAccount)

                for action in actions {
                    let rpcAction = action.walletRpc
                    let signature = try await ethSigner.signTypedData(AnyCodable(rpcAction.params))
                    signatures.append(signature)
                }

                // 3. Confirm payment with signatures
                let result = try await WalletKit.instance.Pay.confirmPayment(
                    paymentId: paymentId,
                    optionId: option.id,
                    signatures: signatures,
                    collectedData: nil,
                    maxPollMs: 60000
                )

                print("Payment confirmed: \(result)")
                self.paymentResultInfo = result

                switch result.status {
                case .succeeded, .processing:
                    self.resultType = .success
                case .cancelled:
                    self.resultType = .cancelled
                case .failed:
                    self.resultType = .generic(message: "Payment failed.")
                case .expired:
                    self.resultType = .expired
                case .requiresAction:
                    self.resultType = .generic(message: "Additional action required.")
                }
                self.currentStep = .result

                // Notify balances screen to refresh
                NotificationCenter.default.post(name: .paymentCompleted, object: nil)

                // Auto-dismiss after 3s in auto-pay mode (NFC tap-to-pay)
                if self.autoPayMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        self?.dismiss()
                    }
                }

            } catch {
                self.resultType = Self.detectResultType(from: error)
                self.currentStep = .result
            }
        }
    }

    func dismiss() {
        dismissAction?()
    }

    // MARK: - Error Detection

    /// Map SDK typed errors to result types, with string fallback
    static func detectResultType(from error: Error) -> PayResultType {
        // Match on typed SDK errors first
        if let e = error as? GetPaymentOptionsError {
            switch e {
            case .PaymentExpired:
                return .expired
            case .PaymentNotFound(let msg):
                // Cancelled payments may surface as NotFound — check inner message
                let lowered = msg.lowercased()
                if lowered.contains("cancelled") || lowered.contains("canceled") {
                    return .cancelled
                }
                return .notFound
            default:
                break
            }
        }
        if let e = error as? ConfirmPaymentError {
            switch e {
            case .PaymentExpired, .RouteExpired, .QuoteExpired:
                return .expired
            case .PaymentNotFound(let msg):
                let lowered = msg.lowercased()
                if lowered.contains("cancelled") || lowered.contains("canceled") {
                    return .cancelled
                }
                return .notFound
            case .PollingTimeout:
                return .expired
            default:
                break
            }
        }
        // Fallback: string matching on localizedDescription
        return detectErrorType(from: error.localizedDescription)
    }

    static func detectErrorType(from message: String) -> PayResultType {
        let lowered = message.lowercased()
        if lowered.contains("insufficient") || lowered.contains("balance") || lowered.contains("funds") {
            return .insufficientFunds
        }
        if lowered.contains("expired") || lowered.contains("timeout") {
            return .expired
        }
        if lowered.contains("cancelled") || lowered.contains("canceled") {
            return .cancelled
        }
        if lowered.contains("not found") || lowered.contains("404") {
            return .notFound
        }
        return .generic(message: message)
    }

}

