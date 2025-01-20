import Foundation
import Combine


enum L2: String {
    case Arbitrium
    case Optimism
    case Base
}

final class SendStableCoinPresenter: ObservableObject, SceneViewModel {
    @Published var selectedNetwork: L2 = .Base

    let router: SendStableCoinRouter
    let importAccount: ImportAccount

    init(router: SendStableCoinRouter,
         importAccount: ImportAccount) {
        self.router = router

    }

    func set(network: L2) {
        selectedNetwork = network
    }

    func upgradeToSmartAccount() {
        router.presentUpgradeToSmartAccount(importAccount: importAccount, network: selectedNetwork)
    }
}


UpgradeToSmartAccountPresenter
UpgradeToSmartAccountView
UpgradeToSmartAccountModule
UpgradeToSmartAccountRouter
