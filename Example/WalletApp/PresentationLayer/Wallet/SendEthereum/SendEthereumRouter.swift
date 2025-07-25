//import UIKit
//import ReownWalletKit
//
//final class SendEthereumRouter {
//    weak var viewController: UIViewController!
//    
//    private let app: Application
//    
//    init(app: Application) {
//        self.app = app
//    }
//    
//    func dismiss() {
//        viewController.dismiss(animated: true)
//    }
//    
//    func presentCATransaction(call: Any?, from: String, chainId: Blockchain, importAccount: ImportAccount, uiFields: Any?) {
//        CATransactionModule.create(
//            app: app, 
//            sessionRequest: nil, 
//            importAccount: importAccount, 
//            call: call, 
//            from: from, 
//            chainId: chainId, 
//            uiFields: uiFields
//        ).presentFullScreen(from: viewController, transparentBackground: false)
//    }
//} 
