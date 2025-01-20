import Foundation
import UIKit

final class SendStableCoinRouter {
    weak var viewController: UIViewController!

    private let app: Application

    init(app: Application) {
        self.app = app
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.viewController?.dismiss()
        }
    }

    func presentUpgradeToSmartAccount(importAccount: ImportAccount, network: L2) {

    }
}
