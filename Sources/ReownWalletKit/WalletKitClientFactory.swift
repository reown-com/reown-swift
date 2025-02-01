import Foundation
import YttriumWrapper

struct WalletKitClientFactory {
    static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol,
        config: WalletKit.Config
    ) -> WalletKitClient {
        let chainAbstractionClient = ChainAbstractionClient(projectId: Networking.projectId)
        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            chainAbstractionClient: chainAbstractionClient
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
        let chainAbstractionClient = ChainAbstractionClient(projectId: projectId)
        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            chainAbstractionClient: chainAbstractionClient
        )
    }
#endif

}
