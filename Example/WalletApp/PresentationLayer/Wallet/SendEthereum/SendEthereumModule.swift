import SwiftUI

final class SendEthereumModule {
    @discardableResult
    static func create(app: Application, importAccount: ImportAccount) -> UIViewController {
        let router = SendEthereumRouter(app: app)
        let presenter = SendEthereumPresenter(router: router, importAccount: importAccount)
        let view = SendEthereumView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)
        
        router.viewController = viewController
        
        return viewController
    }
} 