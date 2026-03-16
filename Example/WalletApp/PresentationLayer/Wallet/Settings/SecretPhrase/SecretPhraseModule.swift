import SwiftUI

final class SecretPhraseModule {

    @discardableResult
    static func create(app: Application) -> UIViewController {
        let presenter = SecretPhrasePresenter(accountStorage: app.accountStorage)
        let view = SecretPhraseView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)
        return viewController
    }
}
