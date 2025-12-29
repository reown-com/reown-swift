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

    func presentPay(importAccount: ImportAccount) {
        // Test payment link - in production this would come from deep link or QR code
        let testPaymentLink = "https://pay.walletconnect.com/p/test-payment-id"
        let accounts = ["eip155:1:\(importAccount.address)"]
        let signer = DefaultPaymentSigner(account: importAccount)
        
        PayModule.create(
            app: app,
            paymentLink: testPaymentLink,
            accounts: accounts,
            signer: signer
        )
        .presentFullScreen(from: UIApplication.currentWindow.rootViewController!, transparentBackground: true)
    }

    func dismiss() {
        viewController.navigationController?.dismiss()
    }
}
