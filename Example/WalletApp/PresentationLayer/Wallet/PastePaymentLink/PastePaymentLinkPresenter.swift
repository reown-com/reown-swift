import UIKit
import Combine

final class PastePaymentLinkPresenter: ObservableObject {
    private let router: PastePaymentLinkRouter
    private var disposeBag = Set<AnyCancellable>()

    let onValue: (String) -> Void
    let onError: (Error) -> Void
    
    init(
        router: PastePaymentLinkRouter,
        onValue: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.router = router
        self.onValue = onValue
        self.onError = onError
    }
    
    func onSubmit(_ urlString: String) {
        // Extract payment link - support both full URL and just the pid parameter
        let paymentLink = extractPaymentLink(from: urlString)
        onValue(paymentLink)
    }
    
    private func extractPaymentLink(from input: String) -> String {
        // If it's already a full URL, return as is
        if input.starts(with: "http") {
            return input
        }
        
        // If it looks like just a payment ID, construct the URL
        if input.starts(with: "pay_") {
            return "https://pay.walletconnect.com/?pid=\(input)"
        }
        
        return input
    }
}

// MARK: - SceneViewModel
extension PastePaymentLinkPresenter: SceneViewModel {

}
