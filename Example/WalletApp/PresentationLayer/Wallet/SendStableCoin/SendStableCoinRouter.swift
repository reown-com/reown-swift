import Foundation
import UIKit
import ReownWalletKit

final class SendStableCoinRouter {
    weak var viewController: UIViewController!

    private let app: Application

    init(app: Application) {
        self.app = app
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.viewController?.dismiss()
        }
    }

    func presentUpgradeToSmartAccount(
        importAccount: ImportAccount,
        network: L2,
        prepareDeployParams: PrepareDeployParams,
        auth: PreparedGasAbstractionAuthorization,
        chainId: Blockchain
    ) {

        UpgradeToSmartAccountModule.create(
            app: app,
            importAccount: importAccount,
            network: network,
            prepareDeployParams: prepareDeployParams,
            auth: auth,
            chainId: chainId
        )
        .present(from: viewController)
    }
}
