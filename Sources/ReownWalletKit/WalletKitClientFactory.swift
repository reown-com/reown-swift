import Foundation
import YttriumWrapper

struct WalletKitClientFactory {
    static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol,
        config: WalletKit.Config
    ) -> WalletKitClient {
        var safesManager: SafesManager? = nil
        if let pimlicoApiKey = config.pimlicoApiKey {
            safesManager = SafesManager(pimlicoApiKey: pimlicoApiKey)
        }
        let chainAbstractionClient = ChainAbstractionClient(projectId: Networking.projectId)
        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            smartAccountsManager: safesManager,
            chainAbstractionClient: chainAbstractionClient
        )
    }
}
