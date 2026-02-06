import UIKit
import Combine
import ReownWalletKit
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
                let response = try await WalletKit.instance.Pay.getPaymentOptions(
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

                // If no data collection required, skip intro and go directly to confirmation
                if response.collectData == nil {
                    self.currentStep = .confirmation
                }

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
        switch currentStep {
        case .intro:
            dismiss()
        case .nameInput:
            currentStep = .intro
        case .dateOfBirth:
            currentStep = .nameInput
        case .confirmation:
            // If info capture was required, go back to dateOfBirth
            // If no data collection required (intro was skipped), dismiss entirely
            if paymentOptionsResponse?.collectData != nil {
                currentStep = .dateOfBirth
            } else {
                dismiss()
            }
        case .confirming, .success:
            // Don't allow back navigation from these states
            break
        }
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

        // Switch to confirming state immediately
        currentStep = .confirming

        Task { @MainActor in
            do {
                // 1. Get required actions for the selected option
                // Use paymentId from getPaymentOptions response (Yttrium already extracted it)
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
                
                // 3. Collect user data if required (travel rule)
                var collectedData: [CollectDataFieldResult]? = nil
                if let collectDataAction = paymentOptionsResponse?.collectData {
                    collectedData = collectDataAction.fields.map { field -> CollectDataFieldResult in
                        let value = resolveFieldValue(for: field)
                        return CollectDataFieldResult(id: field.id, value: value)
                    }
                }
                
                // 4. Confirm payment with signatures and collected data
                let result = try await WalletKit.instance.Pay.confirmPayment(
                    paymentId: paymentId,
                    optionId: option.id,
                    signatures: signatures,
                    collectedData: collectedData,
                    maxPollMs: 60000
                )
                
                print("Payment confirmed: \(result)")
                self.currentStep = .success

                // Notify balances screen to refresh
                NotificationCenter.default.post(name: .paymentCompleted, object: nil)
                
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
        
        // Check for full name field first (combined first + last name)
        if fieldId == "fullname" || fieldId == "full_name" || fieldId == "name" ||
           fieldName.contains("full name") {
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        }
        // Individual name fields
        else if fieldId == "firstname" || fieldId == "first_name" || fieldName.contains("first") {
            return firstName
        } else if fieldId == "lastname" || fieldId == "last_name" || fieldName.contains("last") {
            return lastName
        }
        // Date of birth
        else if fieldId == "dob" || fieldId == "dateofbirth" || fieldId == "date_of_birth" || fieldName.contains("birth") {
            return formattedDateOfBirth
        }
        
        print("💳 [Pay] Warning: Unknown field - id: \(field.id), name: \(field.name)")
        return ""
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
