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
    
    func presentScannerOptions(onScanQR: @escaping () -> Void, onPasteURL: @escaping () -> Void) {
        let vc = ScannerOptionsModule.create(
            app: app,
            onScanQR: onScanQR,
            onPasteURL: onPasteURL,
            onClose: { [weak self] in
                self?.dismissPresented()
            }
        )
        UIApplication.currentWindow.rootViewController?.present(vc, animated: true)
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

    func startPayFlow(paymentLink: String, importAccount: ImportAccount) {
        // Pass accounts for multiple chains like Kotlin does
        let address = importAccount.account.address
        let accounts = [
            "eip155:1:\(address)",      // Ethereum Mainnet
            "eip155:137:\(address)",    // Polygon
            "eip155:8453:\(address)"    // Base
        ]
        
        PayModule.create(
            app: app,
            paymentLink: paymentLink,
            accounts: accounts,
            importAccount: importAccount
        )
        .presentFullScreen(from: UIApplication.currentWindow.rootViewController!, transparentBackground: true)
    }

    func dismiss() {
        viewController.navigationController?.dismiss()
    }

    func dismissPresented() {
        UIApplication.currentWindow.rootViewController?.dismiss(animated: true)
    }

    func dismissToPresent(then completion: @escaping () -> Void) {
        if let presented = UIApplication.currentWindow.rootViewController?.presentedViewController {
            presented.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
    }
}
