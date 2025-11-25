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
            let rpc = try await interactor.buildPayment(paymentId: paymentId)
            let signature = try await interactor.sign(rpc: rpc)
            try await interactor.submit(paymentId: paymentId, signature: signature)
            showSuccess = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func dismiss() {
        router.dismiss()
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
