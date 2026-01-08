import UIKit
import Combine
import WalletConnectPay
import Commons

enum PayFlowStep: Int, CaseIterable {
    case intro = 0
    case nameInput = 1
    case dateOfBirth = 2
    case confirmation = 3
    case confirming = 4  // Loading state while payment is being processed
    case success = 5
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
    
    // User info for travel rule
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var dateOfBirth: Date = {
        // Default to 1990-01-01
        var components = DateComponents()
        components.year = 1990
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()
    
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
                print("💳 [Pay] getPaymentOptions response: \(response)")
                print("💳 [Pay] collectData: \(String(describing: response.collectData))")
                print("💳 [Pay] collectData fields: \(String(describing: response.collectData?.fields))")
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
        // Check if travel rule data collection is required
        let collectData = paymentOptionsResponse?.collectData
        print("💳 [Pay] startFlow - collectData: \(String(describing: collectData))")
        print("💳 [Pay] startFlow - paymentOptionsResponse: \(String(describing: paymentOptionsResponse))")
        
        if collectData != nil {
            currentStep = .nameInput
        } else {
            // No user data needed, go directly to confirmation
            currentStep = .confirmation
        }
    }
    
    func submitUserInfo() {
        guard !firstName.isEmpty && !lastName.isEmpty else {
            errorMessage = "Please enter your first and last name"
            showError = true
            return
        }
        currentStep = .dateOfBirth
    }
    
    func submitDateOfBirth() {
        currentStep = .confirmation
    }
    
    /// Format date of birth as YYYY-MM-DD for API
    var formattedDateOfBirth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: dateOfBirth)
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
        
        // Switch to confirming state immediately
        currentStep = .confirming
        
        Task { @MainActor in
            do {
                // 1. Get required actions for the selected option
                let paymentId = extractPaymentId(from: paymentLink)
                let actions = try await WalletConnectPay.instance.getRequiredPaymentActions(
                    paymentId: paymentId,
                    optionId: option.id
                )
                self.requiredActions = actions
                
                // 2. Sign all wallet RPC actions
                var signatures: [String] = []
                let ethSigner = ETHSigner(importAccount: importAccount)
                
                for action in actions {
                    let rpcAction = action.walletRpc
                    let authorizationJson = try await ethSigner.signTypedData(AnyCodable(rpcAction.params))
                    let signature = try extractSignatureFromAuthorization(authorizationJson)
                    signatures.append(signature)
                }
                
                // 3. Collect user data if required (travel rule)
                var collectedData: [CollectDataFieldResult]? = nil
                if let collectDataAction = paymentOptionsResponse?.collectData {
                    collectedData = collectDataAction.fields.map { field -> CollectDataFieldResult in
                        let value = resolveFieldValue(for: field)
                        return CollectDataFieldResult(id: field.id, value: value)
                    }
                }
                
                // 4. Confirm payment with signatures and collected data
                let result = try await WalletConnectPay.instance.confirmPayment(
                    paymentId: paymentId,
                    optionId: option.id,
                    signatures: signatures,
                    collectedData: collectedData,
                    maxPollMs: 60000
                )
                
                print("Payment confirmed: \(result)")
                self.currentStep = .success
                
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
                // Go back to confirmation on error
                self.currentStep = .confirmation
            }
        }
    }
    
    func dismiss() {
        router.dismiss()
    }
    
    // MARK: - Private Methods
    
    private func resolveFieldValue(for field: CollectDataField) -> String {
        let fieldId = field.id.lowercased()
        let fieldName = field.name.lowercased()
        
        if fieldId == "firstname" || fieldName.contains("first") {
            return firstName
        } else if fieldId == "lastname" || fieldName.contains("last") {
            return lastName
        } else if fieldId == "dob" || fieldName.contains("birth") {
            return formattedDateOfBirth
        }
        return ""
    }
    
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
    private func extractSignatureFromAuthorization(_ authorizationJson: String) throws -> String {
        let auth = try JSONDecoder().decode(Erc3009AuthorizationResponse.self, from: Data(authorizationJson.utf8))
        let rHex = auth.r.stripHexPrefix()
        let sHex = auth.s.stripHexPrefix()
        let vHex = String(format: "%02x", auth.v)
        return "0x\(rHex)\(sHex)\(vHex)"
    }
}

// MARK: - Response Types

private struct Erc3009AuthorizationResponse: Decodable {
    let v: Int
    let r: String
    let s: String
}

private extension String {
    func stripHexPrefix() -> String {
        hasPrefix("0x") ? String(dropFirst(2)) : self
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
