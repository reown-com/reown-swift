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
        var gasAbstractionClientsManager: GasAbstractionClientsManager? = nil
        if let pimlicoApiKey = config.pimlicoApiKey {
            safesManager = SafesManager(pimlicoApiKey: pimlicoApiKey)
            gasAbstractionClientsManager = GasAbstractionClientsManager(pimlicoApiKey: pimlicoApiKey)
        }
        let chainAbstractionClient = ChainAbstractionClient(projectId: Networking.projectId)
        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            smartAccountsManager: safesManager,
            chainAbstractionClient: chainAbstractionClient,
            gasAbstractionClientsManager: gasAbstractionClientsManager
        )
    }

#if DEBUG
    static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol,
        config: WalletKit.Config,
        projectId: String
    ) -> WalletKitClient {
        var safesManager: SafesManager? = nil
        var gasAbstractionClientsManager: GasAbstractionClientsManager? = nil
        if let pimlicoApiKey = config.pimlicoApiKey {
            safesManager = SafesManager(pimlicoApiKey: pimlicoApiKey)
            gasAbstractionClientsManager = GasAbstractionClientsManager(pimlicoApiKey: pimlicoApiKey)
        }
        let chainAbstractionClient = ChainAbstractionClient(projectId: projectId)
        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            smartAccountsManager: safesManager,
            chainAbstractionClient: chainAbstractionClient,
            gasAbstractionClientsManager: gasAbstractionClientsManager
        )
    }
#endif

}
