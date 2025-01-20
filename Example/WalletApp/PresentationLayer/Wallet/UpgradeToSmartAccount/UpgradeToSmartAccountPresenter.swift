import Foundation
import ReownWalletKit

final class UpgradeToSmartAccountPresenter: ObservableObject, SceneViewModel {
    @Published var selectedNetwork: L2
    @Published var doNotAskAgain = false

    let router: UpgradeToSmartAccountRouter
    let importAccount: ImportAccount

    init(router: UpgradeToSmartAccountRouter,
         importAccount: ImportAccount,
         network: L2) {
        self.router = router
        self.importAccount = importAccount
        self.selectedNetwork = network
    }

    /// Called when user taps the 'Sign & Upgrade' button
    func signAndUpgrade() {
        // TODO: Implement any logic needed before upgrading
        // For now, just dismiss or call into router if needed
        router.dismiss()
    }

    /// Called when user taps the 'Cancel' or 'X' button
    func cancel() {
        router.dismiss()
    }
}
