import SwiftUI

final class PayModule {
    @discardableResult
    static func create(
        app: Application,
        paymentLink: String,
        accounts: [String],
        importAccount: ImportAccount
    ) -> UIViewController {
        let router = PayRouter(app: app)
        let presenter = PayPresenter(
            router: router,
            paymentLink: paymentLink,
            accounts: accounts,
            importAccount: importAccount
        )
        let view = PayContainerView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)

        router.viewController = viewController

        return viewController
    }
}
