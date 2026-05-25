import UIKit
import Combine
import ReownWalletKit
import Commons

/// Loading-screen copy. `subtitle` is optional and renders smaller / secondary
/// beneath `title` (used for the multi-line one-time-setup message). Equatable
/// so SwiftUI can drive the cross-fade animation off the value.
struct PayLoadingMessage: Equatable, Hashable {
    let title: String
    var subtitle: String? = nil
}

enum PayFlowStep: Int, CaseIterable {
    case loading = 0
    case options = 1
    case whyInfoRequired = 2
    case webviewDataCollection = 3
    case summary = 4
    case gasFee = 5
    case confirming = 6
    case result = 7
}

final class PayPresenter: ObservableObject {
    var dismissAction: (() -> Void)?
    var scanNewQRAction: (() -> Void)?
    private let importAccount: ImportAccount
    private var tokenPreferenceStore = PayTokenPreferenceStore()
    private var disposeBag = Set<AnyCancellable>()

    // Trusted IC WebView domains
    private static let trustedICDomains = [
        "dev.pay.walletconnect.com",
        "staging.pay.walletconnect.com",
        "pay.walletconnect.com"
    ]

    // Flow state
    @Published var currentStep: PayFlowStep = .loading
    @Published var showError = false
    @Published var errorMessage = ""

    // Result state
    @Published var resultType: PayResultType = .success
    @Published var loadingMessage: PayLoadingMessage = .init(title: "Preparing your payment...")

    // Payment data
    @Published var paymentOptionsResponse: PaymentOptionsResponse?
    @Published var selectedOption: PaymentOption?

    // Per-option preload state, keyed by option.id.
    @Published var optionFeeEstimates: [String: FeeEstimate] = [:]
    @Published var loadingFeeOptionIds: Set<String> = []

    // Gas explainer routing state
    @Published var gasFeeOption: PaymentOption?
    private var gasFeeReturnStep: PayFlowStep = .options

    /// True when we reached `.summary` directly from `.loading` (single option
    /// or remembered last-paid token). In that case the summary header hides
    /// its back button — there is no previous step to return to.
    @Published var summaryEnteredDirectly: Bool = false

    /// Per-option preload sequence counters. A stale fetch for option A cannot
    /// overwrite a fresh state for option B. Bumped per preload kickoff.
    private var optionSeqs: [String: Int] = [:]
    /// Global session counter — bumped on every `loadPaymentOptions` call so
    /// all in-flight estimates from a previous QR scan are discarded.
    private var paymentSessionSeq: Int = 0

    /// Local expiry safety margin — refuse to broadcast a payment whose
    /// `expiresAt` is within this window of now.
    private static let expiryGuardMs: Int64 = 10_000

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

    init(paymentLink: String, accounts: [String], importAccount: ImportAccount) {
        self.paymentLink = paymentLink
        self.accounts = accounts
        self.importAccount = importAccount
        loadPaymentOptions()
    }

    // MARK: - Public Methods

    func loadPaymentOptions() {
        loadingMessage = PayLoadingMessage(title: "Preparing your payment...")
        currentStep = .loading
        paymentSessionSeq += 1
        optionSeqs.removeAll()
        optionFeeEstimates.removeAll()
        loadingFeeOptionIds.removeAll()
        let sessionSeq = paymentSessionSeq

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await WalletKit.instance.Pay.getPaymentOptions(
                    paymentLink: paymentLink,
                    accounts: accounts,
                    includePaymentInfo: true
                )
                guard sessionSeq == self.paymentSessionSeq else { return }
                self.paymentOptionsResponse = response

                if response.options.isEmpty {
                    self.resultType = .insufficientFunds
                    self.currentStep = .result
                    return
                }

                let preferredUnit = self.tokenPreferenceStore.lastPaidTokenUnit
                let preferred = PayTokenPreferenceStore.findPreferredOption(response.options, lastPaidUnit: preferredUnit)

                // Single-option flows: pre-select the only choice.
                // Multi-option flows: only auto-select when the user has a
                // remembered preferred token and skip straight to review when
                // there's no IC step. Otherwise leave selection nil so the
                // user actively taps a row on the select screen. Mirrors
                // Flutter PR #377's "no auto-pre-pick" behavior.
                if response.options.count == 1 {
                    self.selectedOption = response.options.first
                } else {
                    self.selectedOption = preferred
                }

                self.preloadOptionFees(options: response.options, sessionSeq: sessionSeq)

                let goDirectToReview = (response.options.count == 1 && response.collectData == nil)
                    || (preferred != nil && response.collectData == nil)
                if goDirectToReview {
                    self.summaryEnteredDirectly = true
                    self.currentStep = .summary
                } else {
                    self.summaryEnteredDirectly = false
                    self.currentStep = .options
                }
            } catch {
                self.resultType = Self.detectResultType(from: error)
                self.currentStep = .result
            }
        }
    }

    /// Kicks off a parallel estimate per option. Approval requirement is read
    /// directly off `option.actions` returned by `getPaymentOptions`; no
    /// committal `getRequiredPaymentActions` call is made for preview.
    private func preloadOptionFees(options: [PaymentOption], sessionSeq: Int) {
        for option in options where PaymentUtil.requiresApproval(option: option) {
            let optionId = option.id
            let nextSeq = (optionSeqs[optionId] ?? 0) + 1
            optionSeqs[optionId] = nextSeq
            loadingFeeOptionIds.insert(optionId)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let service = PayTransactionService(projectId: InputConfig.projectId)
                let estimate = await service.estimateTransactionFeeFiat(option: option)

                guard sessionSeq == self.paymentSessionSeq,
                      self.optionSeqs[optionId] == nextSeq else { return }
                self.loadingFeeOptionIds.remove(optionId)
                if let estimate {
                    self.optionFeeEstimates[optionId] = estimate
                }
            }
        }
    }

    /// Called from options screen when user taps the primary button
    func continueFromOptions() {
        guard selectedOption != nil else { return }
        summaryEnteredDirectly = false
        if let collectData = collectData,
           let url = collectData.url, !url.isEmpty {
            currentStep = .webviewDataCollection
        } else {
            currentStep = .summary
        }
    }

    /// Called when IC WebView completes successfully
    func onICWebViewComplete() {
        summaryEnteredDirectly = false
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
              components.scheme?.lowercased() == "https",
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
            } else if paymentOptions.count > 1 {
                currentStep = .options
            } else {
                dismiss()
            }
        case .gasFee:
            currentStep = gasFeeReturnStep
        case .confirming, .result:
            // Don't allow back navigation from these states
            break
        }
    }

    func showWhyInfoRequiredScreen() {
        currentStep = .whyInfoRequired
    }

    /// Shows the gas-fee explainer for an option without changing the
    /// presenter's `selectedOption`. The originating step is remembered so
    /// `goBack()` returns there.
    func showGasFeeExplainer(for option: PaymentOption) {
        gasFeeOption = option
        gasFeeReturnStep = currentStep == .options ? .options : .summary
        currentStep = .gasFee
    }

    func selectOption(_ option: PaymentOption) {
        selectedOption = option
    }

    func fee(for option: PaymentOption) -> FeeState {
        if !PaymentUtil.requiresApproval(option: option) {
            return .notRequired
        }
        if let estimate = optionFeeEstimates[option.id] {
            return .value(estimate)
        }
        if loadingFeeOptionIds.contains(option.id) {
            return .loading
        }
        return .unavailable
    }

    func requiresApproval(for option: PaymentOption) -> Bool {
        PaymentUtil.requiresApproval(option: option)
    }

    /// Returns true when `paymentInfo.expiresAt` is within `expiryGuardMs` of
    /// the current time (or already past). Matches the Kotlin sample's guard.
    private func isPaymentExpiredLocally() -> Bool {
        guard let expiresAtSec = paymentInfo?.expiresAt else { return false }
        let expiresAtMs = expiresAtSec * 1_000
        let nowMs = Int64(Date().timeIntervalSince1970 * 1_000)
        return expiresAtMs <= nowMs + Self.expiryGuardMs
    }

    func confirmPayment() {
        guard let option = selectedOption,
              let paymentId = paymentOptionsResponse?.paymentId else {
            errorMessage = "Please select a payment option"
            showError = true
            return
        }

        // Local expiry guard — avoid racing an effectively-expired payment
        // through the RPC flow.
        if isPaymentExpiredLocally() {
            resultType = .expired
            currentStep = .result
            return
        }

        // Switch to confirming state. The exact message is set below once we
        // know whether this is a single- or multi-step flow.
        loadingMessage = PayLoadingMessage(title: "Processing your payment...")
        currentStep = .confirming

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // Committal call — exactly once per payment, at the moment the
                // user confirms. There is no preview/cache path. From this
                // point the wallet is obligated to execute every action and
                // call `confirmPayment`.
                let actions = try await WalletKit.instance.Pay.getRequiredPaymentActions(
                    paymentId: paymentId,
                    optionId: option.id
                )

                let tokenSymbol = option.amount.display.assetSymbol
                let txService = PayTransactionService(projectId: InputConfig.projectId)
                let ethSigner = ETHSigner(importAccount: importAccount)
                var signatures: [String] = []
                let isMultiStep = PaymentUtil.shouldShowSetupLoader(actions: actions)

                for action in actions {
                    switch action.walletRpc.method {
                    case "eth_sendTransaction":
                        self.loadingMessage = PayLoadingMessage(
                            title: "Setting up \(tokenSymbol)",
                            subtitle: "This usually takes a few seconds. Future \(tokenSymbol) payments will skip this step."
                        )
                        let txHash = try await txService.sendTransactionAndWait(
                            action: action,
                            importAccount: self.importAccount
                        )
                        signatures.append(txHash)
                    case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
                        self.loadingMessage = PayLoadingMessage(
                            title: isMultiStep ? "Finalizing your payment…" : "Processing your payment..."
                        )
                        let signature = try await ethSigner.signTypedData(
                            AnyCodable(action.walletRpc.params)
                        )
                        signatures.append(signature)
                    default:
                        throw PayPresenterError.unsupportedWalletRpcMethod(action.walletRpc.method)
                    }
                }

                self.loadingMessage = PayLoadingMessage(
                    title: isMultiStep ? "Finalizing your payment…" : "Processing your payment..."
                )
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
                    self.tokenPreferenceStore.lastPaidTokenUnit = option.amount.unit
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

            } catch {
                self.resultType = Self.detectResultType(from: error)
                self.currentStep = .result
            }
        }
    }

    enum PayPresenterError: Error, LocalizedError {
        case unsupportedWalletRpcMethod(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedWalletRpcMethod(let m):
                return "Unsupported wallet RPC method: \(m)"
            }
        }
    }

    func dismiss() {
        dismissAction?()
    }

    func primaryResultAction() {
        switch resultType {
        case .expired:
            scanNewQRAction?()
        case .success, .insufficientFunds, .cancelled, .notFound, .generic:
            dismiss()
        }
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
