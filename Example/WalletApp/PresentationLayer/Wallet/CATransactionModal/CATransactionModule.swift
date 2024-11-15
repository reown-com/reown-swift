import Foundation
import UIKit

final class CATransactionModule {
    @discardableResult
    static func create(
        app: Application
    ) -> UIViewController {
        let presenter = CATransactionPresenter()
        let view = CATransactionView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)


        return viewController
    }
}
