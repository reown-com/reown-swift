import UIKit

import ReownWalletKit
import WalletConnectNotify

final class MainRouter {
    weak var viewController: UIViewController!

    private let app: Application

    init(app: Application) {
        self.app = app
    }

    func walletViewController(importAccount: ImportAccount) -> UIViewController {
        return WalletModule.create(app: app, importAccount: importAccount)
            .wrapToNavigationController()
    }

    func notificationsViewController(importAccount: ImportAccount) -> UIViewController {
        return NotificationsModule.create(app: app, importAccount: importAccount)
            .wrapToNavigationController()
    }

    func settingsViewController(importAccount: ImportAccount) -> UIViewController {
        return SettingsModule.create(app: app, importAccount: importAccount)
            .wrapToNavigationController()
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
