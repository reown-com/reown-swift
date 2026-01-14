import SwiftUI

final class PastePaymentLinkModule {
    @discardableResult
    static func create(
        app: Application,
        onValue: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) -> UIViewController {
        let router = PastePaymentLinkRouter(app: app)
        let presenter = PastePaymentLinkPresenter(
            router: router,
            onValue: onValue,
            onError: onError
        )
        let view = PastePaymentLinkView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)

        router.viewController = viewController

        return viewController
    }
}
