import SwiftUI

final class WelcomeModule {
    @discardableResult
    static func create(app: Application) -> UIViewController {
        let router = WelcomeRouter(app: app)
        let solanaAccountStorage = SolanaAccountStorage()
        let suiAccountStorage = SuiAccountStorage()
        let tonAccountStorage = TonAccountStorage()
        let interactor = WelcomeInteractor(accountStorage: app.accountStorage, solanaAccountStorage: solanaAccountStorage, suiAccountStorage: suiAccountStorage, tonAccountStorage: tonAccountStorage)
        let presenter = WelcomePresenter(interactor: interactor, router: router)
        let view = WelcomeView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)
        
        router.viewController = viewController
        
        return viewController
    }
}
