import Foundation
import UIKit
import ReownWalletKit

final class SendStableCoinModule {
    @discardableResult
    static func create(
        app: Application,
        importAccount: ImportAccount
    ) -> UIViewController {
        let router = SendStableCoinRouter(app: app)
        let presenter = SendStableCoinPresenter(router: router, importAccount: importAccount)
        let view = SendStableCoinView(presenter: presenter).environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)
        router.viewController = viewController
        return viewController
    }
}


