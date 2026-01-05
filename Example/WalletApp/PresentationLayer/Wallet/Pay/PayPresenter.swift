import UIKit
import Combine
import WalletConnectPay

enum PayFlowStep: Int, CaseIterable {
    case intro = 0
    case nameInput = 1
    case confirmation = 2
}

final class PayPresenter: ObservableObject {
    private let router: PayRouter
    private let signer: PaymentSigner
    private var disposeBag = Set<AnyCancellable>()
    
    // Flow state
    @Published var currentStep: PayFlowStep = .intro
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Payment data
    @Published var paymentOptionsResponse: PaymentOptionsResponse?
    @Published var selectedOption: PaymentOption?
    @Published var requiredActions: [RequiredAction] = []
    
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
    
    init(router: PayRouter, paymentLink: String, accounts: [String], signer: PaymentSigner) {
        self.router = router
        self.paymentLink = paymentLink
        self.accounts = accounts
        self.signer = signer
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
                
                // 2. Sign all required actions
                var signatureResults: [SignatureResult] = []
                
                for action in actions {
                    switch action {
                    case .walletRpc(let rpcAction):
                        // Handle wallet RPC actions (e.g., eth_signTypedData_v4 for permits)
                        if rpcAction.method == "eth_signTypedData_v4" {
                            let signature = try await signer.signTypedData(
                                chainId: rpcAction.chainId,
                                params: rpcAction.params
                            )
                            signatureResults.append(SignatureResult(signature: SignatureValue(value: signature)))
                        } else {
                            // Handle other RPC methods as needed
                            print("Unsupported RPC method: \(rpcAction.method)")
                        }
                    }
                }
                
                // 3. Confirm payment with signatures
                let result = try await WalletConnectPay.instance.confirmPayment(
                    paymentId: paymentId,
                    optionId: option.id,
                    results: signatureResults,
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
        // Format: https://pay.walletconnect.com/p/<payment-id>
        // or walletapp://walletconnectpay?paymentId=<id>
        if let url = URL(string: link),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Check for paymentId query parameter
            if let paymentId = components.queryItems?.first(where: { $0.name == "paymentId" })?.value {
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

// MARK: - Payment Signer Protocol

/// Protocol for signing payment-related messages
/// Implement this protocol to provide signing capabilities for your wallet
protocol PaymentSigner {
    /// Sign typed data (EIP-712)
    /// - Parameters:
    ///   - chainId: The chain ID in CAIP-2 format (e.g., "eip155:1")
    ///   - params: JSON string containing the typed data to sign
    /// - Returns: The signature as a hex string
    func signTypedData(chainId: String, params: String) async throws -> String
}
