import UIKit
import Combine

final class ScanPresenter: ObservableObject {
    private var disposeBag = Set<AnyCancellable>()

    let onValue: (String) -> Void
    let onError: (Error) -> Void
    var dismissAction: (() -> Void)?

    init(
        onValue: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onValue = onValue
        self.onError = onError
    }

    func dismiss() {
        dismissAction?()
    }
}
