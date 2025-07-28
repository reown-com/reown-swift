//import Foundation
//import UIKit
//import SwiftUI
//import ReownWalletKit
//
//final class CATransactionModule {
//    @discardableResult
//    static func create(app: Application, 
//                      sessionRequest: Request?, 
//                      importAccount: ImportAccount, 
//                      call: Any?, // Changed from Call to Any?
//                      from: String, 
//                      chainId: Blockchain, 
//                      uiFields: Any?) -> UIViewController { // Changed from UiFields to Any?
//        let router = CATransactionRouter(app: app)
//        let presenter = CATransactionPresenter(
//            sessionRequest: sessionRequest, 
//            importAccount: importAccount, 
//            router: router, 
//            call: call, 
//            from: from, 
//            chainId: chainId, 
//            uiFields: uiFields)
//        let view = CATransactionView().environmentObject(presenter)
//        let viewController = SceneViewController(viewModel: presenter, content: view)
//
//        router.viewController = viewController
//
//        return viewController
//    }
//}
//
//
