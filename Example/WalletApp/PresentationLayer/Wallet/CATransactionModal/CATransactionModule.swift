import Foundation
import UIKit
import ReownWalletKit

final class CATransactionModule {
    @discardableResult
    static func create(
        app: Application,
        sessionRequest: Request,
        importAccount: ImportAccount,
        routeResponseAvailable: RouteResponseAvailable
    ) -> UIViewController {
        let presenter = CATransactionPresenter(sessionRequest: sessionRequest, importAccount: importAccount, routeResponseAvailable: routeResponseAvailable)
        let view = CATransactionView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)
        return viewController
    }
}
