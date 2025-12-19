import UIKit
import Combine

enum PayFlowStep: Int, CaseIterable {
    case intro = 0
    case nameInput = 1
    case confirmation = 2
}

final class PayPresenter: ObservableObject {
    private let interactor: PayInteractor
    private let router: PayRouter
    private var disposeBag = Set<AnyCancellable>()
    
    // Flow state
    @Published var currentStep: PayFlowStep = .intro
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Payment data
    @Published var paymentOptions: PaymentOptions?
    @Published var userInfo = UserInformation()
    @Published var selectedAsset: PaymentAsset?
    @Published var selectedNetwork: PaymentNetwork?
    
    // Payment ID from deep link or test flow
    private let paymentId: String
    
    init(interactor: PayInteractor, router: PayRouter, paymentId: String? = nil) {
        self.interactor = interactor
        self.router = router
        self.paymentId = paymentId ?? "mock-payment-id"
        loadPaymentOptions()
    }
    
    // MARK: - Public Methods
    
    func loadPaymentOptions() {
        isLoading = true
        Task { @MainActor in
            do {
                let options = try await interactor.getPaymentOptions(paymentId: paymentId)
                self.paymentOptions = options
                // Set default selections
                self.selectedAsset = options.availableAssets.first
                self.selectedNetwork = options.availableNetworks.first
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func startFlow() {
        // Since we always assume travel rule is required, go to name input
        currentStep = .nameInput
    }
    
    func submitUserInfo() {
        guard !userInfo.firstName.isEmpty && !userInfo.lastName.isEmpty else {
            errorMessage = "Please enter your first and last name"
            showError = true
            return
        }
        
        isLoading = true
        Task { @MainActor in
            do {
                try await interactor.submitUserInformation(userInfo, paymentId: paymentId)
                self.currentStep = .confirmation
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func goBack() {
        let currentIndex = currentStep.rawValue
        if currentIndex > 0, let previousStep = PayFlowStep(rawValue: currentIndex - 1) {
            currentStep = previousStep
        } else {
            dismiss()
        }
    }
    
    func selectAsset(_ asset: PaymentAsset) {
        selectedAsset = asset
    }
    
    func selectNetwork(_ network: PaymentNetwork) {
        selectedNetwork = network
    }
    
    func executePayment() {
        guard let asset = selectedAsset, let network = selectedNetwork else {
            errorMessage = "Please select an asset and network"
            showError = true
            return
        }
        
        isLoading = true
        Task { @MainActor in
            do {
                let txHash = try await interactor.executePayment(
                    paymentId: paymentId,
                    assetId: asset.id,
                    networkId: network.id
                )
                print("Payment executed: \(txHash)")
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
