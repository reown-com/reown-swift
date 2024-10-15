import SwiftUI
import Web3
import YttriumWrapper

let mnemonic = "test test test test test test test test test test test junk"

final class MainModule {
    @discardableResult
    static func create(app: Application, importAccount: ImportAccount) -> UIViewController {
        let router = MainRouter(app: app)
        let interactor = MainInteractor()
        let presenter = MainPresenter(router: router, interactor: interactor, importAccount: importAccount, pushRegisterer: app.pushRegisterer, configurationService: app.configurationService)
        let viewController = MainViewController(presenter: presenter)

        configureSmartAccountOnSign(importAccount: importAccount)
        router.viewController = viewController

        return viewController
    }

    static func configureSmartAccountOnSign(importAccount: ImportAccount) {
        let privateKey = importAccount.privateKey
        let ownerAddress = String(importAccount.account.address.dropFirst(2))
    }
}
