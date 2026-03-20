import SwiftUI
import Combine

import ReownWalletKit

final class ConnectionDetailsPresenter: ObservableObject {
    var dismissAction: (() -> Void)?

    let session: Session

    private var disposeBag = Set<AnyCancellable>()

    init(session: Session) {
        self.session = session
    }

    func onDelete() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()
                try await WalletKit.instance.disconnect(topic: session.topic)
                ActivityIndicatorManager.shared.stop()
                await MainActor.run {
                    dismissAction?()
                }
            } catch {
                ActivityIndicatorManager.shared.stop()
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
                try await WalletKit.instance.emit(topic: session.topic, event: Session.Event(name: "chainChanged", data: AnyCodable("1")), chainId: Blockchain("eip155:1")!)
                ActivityIndicatorManager.shared.stop()
            } catch {
                ActivityIndicatorManager.shared.stop()
                print(error)
            }
        }
    }
}
