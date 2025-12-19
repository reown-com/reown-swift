import Foundation
import Combine

final class PayInteractor {
    private let payService: PayServiceProtocol
    
    init(payService: PayServiceProtocol) {
        self.payService = payService
    }
    
    func getPaymentOptions(paymentId: String) async throws -> PaymentOptions {
        try await payService.getPaymentOptions(paymentId: paymentId)
    }
    
    func submitUserInformation(_ info: UserInformation, paymentId: String) async throws {
        try await payService.submitUserInformation(info, paymentId: paymentId)
    }
    
    func executePayment(paymentId: String, assetId: String, networkId: String) async throws -> String {
        try await payService.executePayment(paymentId: paymentId, assetId: assetId, networkId: networkId)
    }
}
