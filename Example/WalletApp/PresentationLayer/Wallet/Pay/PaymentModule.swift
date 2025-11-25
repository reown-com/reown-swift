import SwiftUI
import ReownWalletKit

final class PaymentModule {
    @discardableResult
    static func create(
        app: Application,
        paymentId: String,
        importAccount: ImportAccount
    ) -> UIViewController {
        let router = PaymentRouter(app: app)
        let interactor = PaymentInteractor(paymentService: PaymentService(), account: importAccount)
        let presenter = PaymentPresenter(interactor: interactor, router: router, paymentId: paymentId)
        let view = PaymentView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)
        router.viewController = viewController
        return viewController
    }
}

