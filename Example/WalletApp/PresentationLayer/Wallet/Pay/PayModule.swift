import SwiftUI

final class PayModule {
    @discardableResult
    static func create(app: Application) -> UIViewController {
        let router = PayRouter(app: app)
        let interactor = PayInteractor(payService: MockPayService.shared)
        let presenter = PayPresenter(interactor: interactor, router: router)
        let view = PayContainerView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)

        router.viewController = viewController

        return viewController
    }
}
