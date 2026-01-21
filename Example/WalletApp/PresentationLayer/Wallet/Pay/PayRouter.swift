import UIKit

final class PayRouter {
    weak var viewController: UIViewController!
    
    private let app: Application
    
    init(app: Application) {
        self.app = app
    }
    
    func dismiss() {
        viewController.dismiss(animated: true)
    }
}
