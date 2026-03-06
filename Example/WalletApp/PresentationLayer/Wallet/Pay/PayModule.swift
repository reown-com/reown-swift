import SwiftUI

final class PayModule {
    @discardableResult
    static func create(
        app: Application,
        paymentLink: String,
        accounts: [String],
        importAccount: ImportAccount,
        autoPayMode: Bool = false
    ) -> UIViewController {
        let router = PayRouter(app: app)
        let presenter = PayPresenter(
            router: router,
            paymentLink: paymentLink,
            accounts: accounts,
            importAccount: importAccount,
            autoPayMode: autoPayMode
        )
        let view = PayContainerView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)

        router.viewController = viewController

        return viewController
    }
}
