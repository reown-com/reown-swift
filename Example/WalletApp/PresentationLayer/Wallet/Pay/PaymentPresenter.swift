import Foundation
import Combine
import SwiftUI

final class PaymentPresenter: ObservableObject {
    private let interactor: PaymentInteractor
    private let router: PaymentRouter
    let paymentId: String
    
    @Published var paymentInfo: PaymentInfo?
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSuccess = false
    
    init(interactor: PaymentInteractor, router: PaymentRouter, paymentId: String) {
        self.interactor = interactor
        self.router = router
        self.paymentId = paymentId
    }
    
    @MainActor
    func loadPaymentInfo() async {
        isLoading = true
        do {
            paymentInfo = try await interactor.getPaymentInfo(paymentId: paymentId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    @MainActor
    func pay() async {
        isLoading = true
        do {
            print("[PaymentPresenter] Building payment for paymentId: \(paymentId)")
            let rpc = try await interactor.buildPayment(paymentId: paymentId)
            print("[PaymentPresenter] RPC response: \(rpc)")
            
            print("[PaymentPresenter] Signing RPC...")
            let signature = try await interactor.sign(rpc: rpc)
            print("[PaymentPresenter] Signature/Authorization: \(signature)")
            
            print("[PaymentPresenter] Submitting payment...")
            try await interactor.submit(paymentId: paymentId, signature: signature)
            print("[PaymentPresenter] Payment submitted successfully!")
            
            showSuccess = true
        } catch {
            print("[PaymentPresenter] Error: \(error)")
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func dismiss() {
        router.dismiss()
    }
    
    @MainActor
    func clearError() {
        error = nil
    }
}

extension PaymentPresenter: SceneViewModel {
    var sceneTitle: String? {
        return "Payment"
    }

    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .always
    }
    
    var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
}
