import UIKit
import Combine

final class CATransactionPresenter: ObservableObject {

    private var disposeBag = Set<AnyCancellable>()

    init(
    ) {
        defer { setupInitialState() }
    }

    func dismiss() {
        
    }
}


// MARK: - Private functions
private extension CATransactionPresenter {
    func setupInitialState() {

    }
}

// MARK: - SceneViewModel
extension CATransactionPresenter: SceneViewModel {

}
