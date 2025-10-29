//import Foundation
//import UIKit
//import ReownWalletKit
//
//final class SendStableCoinRouter {
//    weak var viewController: UIViewController!
//
//    private let app: Application
//
//    init(app: Application) {
//        self.app = app
//    }
//
//    func dismiss() {
//        DispatchQueue.main.async { [weak self] in
//            self?.viewController?.dismiss()
//        }
//    }
//
//    func presentCATransaction(call: Any?, from: String, chainId: Blockchain, importAccount: ImportAccount, uiFields: Any?) {
//        CATransactionModule.create(app: app, sessionRequest: nil, importAccount: importAccount, call: call, from: from, chainId: chainId, uiFields: uiFields)
//            .presentFullScreen(from: viewController, transparentBackground: false)
//    }
//
//}
