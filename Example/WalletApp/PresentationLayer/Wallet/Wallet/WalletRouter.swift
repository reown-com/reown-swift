import UIKit

import ReownWalletKit

final class WalletRouter {
    weak var viewController: UIViewController!

    private let app: Application

    init(app: Application) {
        self.app = app
    }
    
    func present(sessionRequest: Request, importAccount: ImportAccount, sessionContext: VerifyContext?) {
        SessionRequestModule.create(app: app, sessionRequest: sessionRequest, importAccount: importAccount, sessionContext: sessionContext)
            .presentFullScreen(from: UIApplication.currentWindow.rootViewController!, transparentBackground: true)
    }
    
    func present(sessionProposal: Session.Proposal, importAccount: ImportAccount, sessionContext: VerifyContext?) {
        SessionProposalModule.create(app: app, importAccount: importAccount, proposal: sessionProposal, context: sessionContext)
            .presentFullScreen(from: viewController, transparentBackground: true)
    }
    
    func presentPaste(onValue: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        PasteUriModule.create(app: app, onValue: onValue, onError: onError)
            .presentFullScreen(from: viewController, transparentBackground: true)
    }
    
    func presentConnectionDetails(session: Session) {
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

    func presentPastePaymentLink(importAccount: ImportAccount) {
        let pasteVC = PastePaymentLinkModule.create(app: app) { [weak self] paymentLink in
            // Dismiss the paste screen first, then present pay flow
            UIApplication.currentWindow.rootViewController?.dismiss(animated: true) {
                self?.startPayFlow(paymentLink: paymentLink, importAccount: importAccount)
            }
        } onError: { error in
            print("Payment link error: \(error.localizedDescription)")
        }
        pasteVC.presentFullScreen(from: UIApplication.currentWindow.rootViewController!, transparentBackground: true)
    }
    
    private func startPayFlow(paymentLink: String, importAccount: ImportAccount) {
        let accounts = [importAccount.account.absoluteString]
        let signer = DefaultPaymentSigner(account: importAccount)
        
        PayModule.create(
            app: app,
            paymentLink: paymentLink,
            accounts: accounts,
            signer: signer
        )
        .presentFullScreen(from: UIApplication.currentWindow.rootViewController!, transparentBackground: true)
    }

    func dismiss() {
        viewController.navigationController?.dismiss()
    }
}
