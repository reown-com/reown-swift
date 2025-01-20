import Foundation
import UIKit
import ReownWalletKit

final class UpgradeToSmartAccountModule {
    @discardableResult
    static func create(
        app: Application,
        importAccount: ImportAccount,
        network: L2,
        prepareDeployParams: PrepareDeployParams,
        auth: PreparedGasAbstractionAuthorization,
        chainId: Blockchain
    ) -> UIViewController {
        let router = UpgradeToSmartAccountRouter(app: app)
        let presenter = UpgradeToSmartAccountPresenter(
            router: router,
            importAccount: importAccount,
            network: network,
            prepareDeployParams: prepareDeployParams,
            auth: auth,
            chainId: chainId
        )

        // Build the SwiftUI view, injecting the presenter
        let view = UpgradeToSmartAccountView(presenter: presenter)

        // Wrap it in your SceneViewController or whichever container
        let viewController = SceneViewController(viewModel: presenter, content: view)
        router.viewController = viewController

        return viewController
    }
}
