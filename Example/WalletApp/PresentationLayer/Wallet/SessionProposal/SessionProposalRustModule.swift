import SwiftUI

import ReownWalletKit
import YttriumWrapper

final class SessionProposalRustModule {

    @discardableResult
    static func create(
        app: Application,
        importAccount: ImportAccount,
        proposal: SessionProposalFfi,
        context: VerifyContext?
    ) -> UIViewController {
        let router = SessionProposalRustRouter(app: app)
        let interactor = SessionProposalRustInteractor()
        let presenter = SessionProposalRustPresenter(
            interactor: interactor,
            router: router,
            importAccount: importAccount,
            proposal: proposal,
            context: context
        )
        let view = SessionProposalRustView().environmentObject(presenter)
        let viewController = SceneViewController(viewModel: presenter, content: view)
        
        router.viewController = viewController
        
        return viewController
    }
} 