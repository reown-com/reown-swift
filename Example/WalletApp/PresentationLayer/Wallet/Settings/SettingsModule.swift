import SwiftUI

final class SettingsModule {

    @discardableResult
    static func create(app: Application, importAccount: ImportAccount) -> UIViewController {
        let router = SettingsRouter(app: app)
        let interactor = SettingsInteractor()
        let presenter = SettingsPresenter(interactor: interactor, router: router, accountStorage: app.accountStorage, importAccount: importAccount)
        let view = SettingsView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)

        router.viewController = viewController

        return viewController
    }

}
