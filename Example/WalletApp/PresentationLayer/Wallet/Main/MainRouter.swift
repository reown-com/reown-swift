import UIKit

import ReownWalletKit

final class MainRouter {
    weak var viewController: UIViewController!

    private let app: Application

    init(app: Application) {
        self.app = app
    }

    func balancesViewController(importAccount: ImportAccount) -> UIViewController {
        let viewModel = BalancesViewModel(app: app, importAccount: importAccount)
        let view = BalancesView().environmentObject(viewModel)
        let viewController = SceneViewController(viewModel: viewModel, content: view)
        viewModel.viewController = viewController
        let nav = viewController.wrapToNavigationController()
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }

    func walletViewController(importAccount: ImportAccount) -> UIViewController {
        let nav = WalletModule.create(app: app, importAccount: importAccount)
            .wrapToNavigationController()
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }

    func settingsViewController(importAccount: ImportAccount) -> UIViewController {
        let nav = SettingsModule.create(app: app, importAccount: importAccount)
            .wrapToNavigationController()
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }
    
    func present(proposal: Session.Proposal, importAccount: ImportAccount, context: VerifyContext?) {
        SessionProposalModule.create(app: app, importAccount: importAccount, proposal: proposal, context: context)
            .presentFullScreen(from: viewController, transparentBackground: true)
    }
    
    func present(sessionRequest: Request, importAccount: ImportAccount, sessionContext: VerifyContext?) {
        SessionRequestModule.create(app: app, sessionRequest: sessionRequest, importAccount: importAccount, sessionContext: sessionContext)
            .presentFullScreen(from: viewController, transparentBackground: true)
    }

    func present(request: AuthenticationRequest, importAccount: ImportAccount, context: VerifyContext?) {
        AuthRequestModule.create(app: app, request: request, importAccount: importAccount, context: context)
            .presentFullScreen(from: viewController, transparentBackground: true)
    }

    func presentCATransaction(sessionRequest: Request, importAccount: ImportAccount, context: VerifyContext?, call: Any?, from: String, chainId: Blockchain, uiFields: Any?) {
//        CATransactionModule.create(app: app, sessionRequest: sessionRequest, importAccount: importAccount, call: call, from: from, chainId: chainId, uiFields: uiFields)
//            .presentFullScreen(from: viewController, transparentBackground: false)
    }

    func dismiss() {
        viewController.dismiss()
    }
}
