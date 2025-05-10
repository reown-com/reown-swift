import Foundation

struct WalletKitClientFactory {
    static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol,
        config: WalletKit.Config,
        projectId: String? = nil
    ) -> WalletKitClient {
        // In debug builds, use the injected projectId if provided.
        // In release builds, always use Networking.projectId.
        let usedProjectId: String = {
            #if DEBUG
            return projectId ?? Networking.projectId
            #else
            return Networking.projectId
            #endif
        }()

        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
        )
    }
}
