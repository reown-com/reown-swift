import SwiftUI

import ReownWalletKit
import WalletConnectYttrium

final class ConnectionDetailsModule {
    @discardableResult
    static func create(app: Application, session: WalletConnectYttrium.Session) -> UIViewController {
        let router = ConnectionDetailsRouter(app: app)
        let presenter = ConnectionDetailsPresenter(
            router: router,
            session: session
        )
        let view = ConnectionDetailsView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)

        router.viewController = viewController

        return viewController
    }
}
