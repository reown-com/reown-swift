import Foundation
import UIKit

final class UpgradeToSmartAccountRouter {
    weak var viewController: UIViewController?
    private let app: Application

    init(app: Application) {
        self.app = app
    }

    /// Dismiss this screen
    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.viewController?.dismiss(animated: true)
        }
    }
}
