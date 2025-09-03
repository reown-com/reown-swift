import UIKit
import Combine

import WalletConnectYttrium
import WalletConnectUtils

final class ConnectionDetailsPresenter: ObservableObject {
    private let router: ConnectionDetailsRouter

    let session: WalletConnectYttrium.Session

    private var disposeBag = Set<AnyCancellable>()

    init(
        router: ConnectionDetailsRouter,
        session: Session
    ) {
        self.router = router
        self.session = session
    }

    func onDelete() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()
                try await WalletKitRust.instance.disconnect(topic: session.topic)
                ActivityIndicatorManager.shared.stop()
                DispatchQueue.main.async {
                    self.router.dismiss()
                }
            } catch {
                ActivityIndicatorManager.shared.stop()
                AlertPresenter.present(message: error.localizedDescription, type: .error)
                print(error)
            }
        }
    }


    func accountReferences(namespace: String) -> [String] {
        session.namespaces[namespace]?.accounts.map { "\($0.namespace):\(($0.reference))" } ?? []
    }

    func changeForMainnet() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()

                let namespaces = ["eip155:1": SettleNamespace(accounts: ["eip155:1:0xcA4FcC31B41f30667895d3318521d957750D4945"], methods: ["personal_sign"], events: [], chains: ["eip155:1"])]
                try await WalletKitRust.instance.update(topic: session.topic, namespaces: namespaces)

                ActivityIndicatorManager.shared.stop()
            } catch {
                ActivityIndicatorManager.shared.stop()
                print(error)
            }
        }
    }
}

// MARK: - Private functions
private extension ConnectionDetailsPresenter {

}

// MARK: - SceneViewModel
extension ConnectionDetailsPresenter: SceneViewModel {

}
