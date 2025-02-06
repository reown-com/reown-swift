import Foundation
import YttriumWrapper

struct WalletKitClientFactory {
    static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol,
        config: WalletKit.Config
    ) -> WalletKitClient {
        let metadata = PulseMetadata(url: nil, bundleId: Bundle.main.bundleIdentifier, packageName: nil, sdkVersion: EnvironmentInfo.sdkName, sdkPlatform: "")
        let chainAbstractionClient = ChainAbstractionClient(projectId: Networking.projectId, pulseMetadata: metadata)
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
        let metadata = PulseMetadata(url: nil, bundleId: Bundle.main.bundleIdentifier, packageName: nil, sdkVersion: EnvironmentInfo.sdkName, sdkPlatform: "")
        let chainAbstractionClient = ChainAbstractionClient(projectId: projectId, pulseMetadata: metadata)
        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            chainAbstractionClient: chainAbstractionClient
        )
    }
#endif

}
