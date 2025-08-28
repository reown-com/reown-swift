import UIKit

import WalletConnectYttrium

final class WalletRouter {
    weak var viewController: UIViewController!

    private let app: Application

    init(app: Application) {
        self.app = app
    }
    
    func present(sessionRequest: Request, importAccount: ImportAccount, sessionContext: VerifyContext?) {
        AlertPresenter.present(message: "not implemented sds", type: .error)
//        SessionRequestModule.create(app: app, sessionRequest: sessionRequest, importAccount: importAccount, sessionContext: sessionContext)
//            .presentFullScreen(from: UIApplication.currentWindow.rootViewController!, transparentBackground: true)
    }
    
    func presentPaste(onValue: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        PasteUriModule.create(app: app, onValue: onValue, onError: onError)
            .presentFullScreen(from: viewController, transparentBackground: true)
    }
    
    func presentConnectionDetails(session: WalletConnectYttrium.Session) {
        ConnectionDetailsModule.create(app: app, session: session)
            .push(from: viewController)
    }

    func presentScan(onValue: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        ScanModule.create(app: app, onValue: onValue, onError: onError)
            .wrapToNavigationController()
            .present(from: viewController)
    }

    func presentSendStableCoin(importAccount: ImportAccount) {
//        SendStableCoinModule.create(app: app, importAccount: importAccount)
//            .wrapToNavigationController()
//            .present(from: viewController)
    }

    func presentSendEthereum(importAccount: ImportAccount) {
//        SendEthereumModule.create(app: app, importAccount: importAccount)
//            .wrapToNavigationController()
//            .present(from: viewController)
    }

    func dismiss() {
        viewController.navigationController?.dismiss()
    }
}
