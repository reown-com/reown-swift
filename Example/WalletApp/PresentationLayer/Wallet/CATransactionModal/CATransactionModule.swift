import Foundation
import UIKit
import ReownWalletKit

final class CATransactionModule {
    @discardableResult
    static func create(
        app: Application,
        sessionRequest: Request?,
        importAccount: ImportAccount,
        call: Call,
        from: String,
        chainId: Blockchain,
        uiFields: UiFields
    ) -> UIViewController {
        let router = CATransactionRouter(app: app)
        let presenter = CATransactionPresenter(sessionRequest: sessionRequest, importAccount: importAccount, router: router, call: call, from: from, chainId: chainId, uiFields: uiFields)
        let view = CATransactionView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)
        router.viewController = viewController
        return viewController
    }
}


