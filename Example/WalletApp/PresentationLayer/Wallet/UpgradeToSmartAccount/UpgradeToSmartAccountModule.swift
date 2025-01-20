import Foundation
import UIKit

final class UpgradeToSmartAccountModule {
    @discardableResult
    static func create(
        app: Application,
        importAccount: ImportAccount,
        network: L2
    ) -> UIViewController {
        let router = UpgradeToSmartAccountRouter(app: app)
        let presenter = UpgradeToSmartAccountPresenter(
            router: router,
            importAccount: importAccount,
            network: network
        )

        // Build the SwiftUI view, injecting the presenter
        let view = UpgradeToSmartAccountView(presenter: presenter)

        // Wrap it in your SceneViewController or whichever container
        let viewController = SceneViewController(viewModel: presenter, content: view)
        router.viewController = viewController

        return viewController
    }
}
