import UIKit
import Combine
import WalletConnectPay
import Commons

enum PayFlowStep: Int, CaseIterable {
    case intro = 0
    case nameInput = 1
    case confirmation = 2
}

final class PayPresenter: ObservableObject {
    private let router: PayRouter
    private let importAccount: ImportAccount
    private var disposeBag = Set<AnyCancellable>()
    
    // Flow state
    @Published var currentStep: PayFlowStep = .intro
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Payment data
    @Published var paymentOptionsResponse: PaymentOptionsResponse?
    @Published var selectedOption: PaymentOption?
    @Published var requiredActions: [Action] = []
    
    // User info for travel rule (kept for future use)
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    
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
    
    init(router: PayRouter, paymentLink: String, accounts: [String], importAccount: ImportAccount) {
        self.router = router
        self.paymentLink = paymentLink
        self.accounts = accounts
        self.importAccount = importAccount
        loadPaymentOptions()
    }
    
    // MARK: - Public Methods
    
    func loadPaymentOptions() {
        isLoading = true
        Task { @MainActor in
            do {
                let response = try await WalletConnectPay.instance.getPaymentOptions(
                    paymentLink: paymentLink,
                    accounts: accounts,
                    includePaymentInfo: true
                )
                self.paymentOptionsResponse = response
                // Select first option by default
                print(response)
                self.selectedOption = response.options.first
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func startFlow() {
        // For now, always assume travel rule is required, go to name input
        currentStep = .nameInput
    }
    
    func submitUserInfo() {
        guard !firstName.isEmpty && !lastName.isEmpty else {
            errorMessage = "Please enter your first and last name"
            showError = true
            return
        }
        
        // Travel rule info will be used in confirmPayment later
        // For now, just move to confirmation
        currentStep = .confirmation
    }
    
    func goBack() {
        let currentIndex = currentStep.rawValue
        if currentIndex > 0, let previousStep = PayFlowStep(rawValue: currentIndex - 1) {
            currentStep = previousStep
        } else {
            dismiss()
        }
    }
    
    func selectOption(_ option: PaymentOption) {
        selectedOption = option
    }
    
    func confirmPayment() {
        guard let option = selectedOption,
              let info = paymentInfo else {
            errorMessage = "Please select a payment option"
            showError = true
            return
        }
        
        isLoading = true
        Task { @MainActor in
            do {
                // 1. Get required actions for the selected option
                let paymentId = extractPaymentId(from: paymentLink)
                let actions = try await WalletConnectPay.instance.getRequiredPaymentActions(
                    paymentId: paymentId,
                    optionId: option.id
                )
                self.requiredActions = actions
                
                // 2. Process all required actions
                var resultItems: [ConfirmPaymentResultItem] = []
                
                let ethSigner = ETHSigner(importAccount: importAccount)
                
                for action in actions {
                    switch action {
                    case .walletRpc(let rpcAction):
                        // Handle wallet RPC actions (e.g., eth_signTypedData_v4 for permits)
                        let authorizationJson = try await ethSigner.signTypedData(AnyCodable(rpcAction.params))
                        print("[PayPresenter] Full authorization JSON: \(authorizationJson)")
                        
                        // Extract signature from authorization JSON
                        // The authorization JSON contains: from, to, value, validAfter, validBefore, nonce, v, r, s
                        let signature = try extractSignatureFromAuthorization(authorizationJson)
                        print("[PayPresenter] Extracted signature: \(signature)")
                        
                        let resultData = WalletRpcResultData(method: rpcAction.method, data: [signature])
                        resultItems.append(.walletRpc(resultData))
                        
                    case .collectData(let collectAction):
                        // Handle collect data actions (e.g., travel rule data collection)
                        var fields: [CollectDataFieldResult] = []
                        for field in collectAction.fields {
                            // Match field by id/name and provide the collected value
                            let value: String
                            let fieldId = field.id.lowercased()
                            let fieldName = field.name.lowercased()
                            
                            print("[PayPresenter] Processing collect data field: id=\(field.id), name=\(field.name), required=\(field.required)")
                            
                            if fieldId == "firstname" || fieldName.contains("first") {
                                value = firstName.isEmpty ? "John" : firstName  // Use placeholder if empty
                            } else if fieldId == "lastname" || fieldName.contains("last") {
                                value = lastName.isEmpty ? "Doe" : lastName  // Use placeholder if empty
                            } else if fieldId == "dob" || fieldName.contains("birth") || fieldName.contains("dob") {
                                // TODO: Add proper date of birth collection UI
                                // For testing, use a placeholder date
                                value = "1990-01-01"
                            } else {
                                // For other fields, use empty string
                                print("[PayPresenter] Unknown field: \(field.id), using empty value")
                                value = ""
                            }
                            print("[PayPresenter] Field \(field.id) = '\(value)'")
                            fields.append(CollectDataFieldResult(id: field.id, value: value))
                        }
                        let resultData = CollectDataResultData(fields: fields)
                        resultItems.append(.collectData(resultData))
                    }
                }
                
                // 3. Confirm payment with results
                print("[PayPresenter] Sending \(resultItems.count) results:")
                for (index, item) in resultItems.enumerated() {
                    switch item {
                    case .walletRpc(let data):
                        print("  [\(index)] walletRpc: method=\(data.method)")
                    case .collectData(let data):
                        print("  [\(index)] collectData: \(data.fields.count) fields")
                    }
                }
                let result = try await WalletConnectPay.instance.confirmPayment(
                    paymentId: paymentId,
                    optionId: option.id,
                    results: resultItems,
                    maxPollMs: 60000
                )
                
                print("Payment confirmed: \(result)")
                self.isLoading = false
                self.dismiss()
                
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func dismiss() {
        router.dismiss()
    }
    
    // MARK: - Private Methods
    
    private func extractPaymentId(from link: String) -> String {
        // Extract payment ID from the payment link
        // Formats:
        // - https://pay.walletconnect.com/p/<payment-id>
        // - https://...?pid=<payment-id>
        // - walletapp://walletconnectpay?paymentId=<id>
        if let url = URL(string: link),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Check for paymentId query parameter
            if let paymentId = components.queryItems?.first(where: { $0.name == "paymentId" })?.value {
                return paymentId
            }
            // Check for pid query parameter (dev environment)
            if let paymentId = components.queryItems?.first(where: { $0.name == "pid" })?.value {
                return paymentId
            }
            // Check for path component
            if let lastPathComponent = url.pathComponents.last, !lastPathComponent.isEmpty && lastPathComponent != "/" {
                return lastPathComponent
            }
        }
        // Fallback: use the whole link as ID
        return link
    }
    
    /// Extract hex signature from ERC-3009 authorization JSON
    /// The authorization contains: from, to, value, validAfter, validBefore, nonce, v, r, s
    /// Returns signature in format: 0x{r}{s}{v}
    private func extractSignatureFromAuthorization(_ authorizationJson: String) throws -> String {
        guard let data = authorizationJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[PayPresenter] Failed to parse authorization JSON")
            throw PaymentError.invalidSignature
        }
        
        print("[PayPresenter] Authorization JSON keys: \(json.keys.sorted())")
        print("[PayPresenter] v=\(String(describing: json["v"])), r=\(String(describing: json["r"])), s=\(String(describing: json["s"]))")
        
        guard let r = json["r"] as? String,
              let s = json["s"] as? String,
              let v = json["v"] as? Int else {
            print("[PayPresenter] Failed to extract v, r, s from authorization")
            print("[PayPresenter] v type: \(type(of: json["v"] ?? "nil")), r type: \(type(of: json["r"] ?? "nil")), s type: \(type(of: json["s"] ?? "nil"))")
            throw PaymentError.invalidSignature
        }
        
        print("[PayPresenter] Extracted v=\(v), r=\(r), s=\(s)")
        
        // Remove 0x prefix if present
        let rHex = r.hasPrefix("0x") ? String(r.dropFirst(2)) : r
        let sHex = s.hasPrefix("0x") ? String(s.dropFirst(2)) : s
        let vHex = String(format: "%02x", v)
        
        print("[PayPresenter] Building signature: r(\(rHex.count) chars) + s(\(sHex.count) chars) + v(\(vHex))")
        
        return "0x\(rHex)\(sHex)\(vHex)"
    }
    
    enum PaymentError: Error, LocalizedError {
        case invalidSignature
        
        var errorDescription: String? {
            switch self {
            case .invalidSignature:
                return "Invalid signature format"
            }
        }
    }
}

// MARK: - SceneViewModel
extension PayPresenter: SceneViewModel {
    var sceneTitle: String? {
        return nil
    }
    
    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .never
    }
}
