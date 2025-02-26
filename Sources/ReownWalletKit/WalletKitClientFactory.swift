import Foundation
import YttriumWrapper

struct WalletKitClientFactory {
    static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol,
        config: WalletKit.Config,
        projectId: String? = nil  
    ) -> WalletKitClient {
        let metadata = PulseMetadata(
            url: nil,
            bundleId: Bundle.main.bundleIdentifier,
            sdkVersion: EnvironmentInfo.sdkName,
            sdkPlatform: "mobile"
        )

        // In debug builds, use the injected projectId if provided.
        // In release builds, always use Networking.projectId.
        let usedProjectId: String = {
            #if DEBUG
            return projectId ?? Networking.projectId
            #else
            return Networking.projectId
            #endif
        }()

        let chainAbstractionClient = ChainAbstractionClient(projectId: usedProjectId, pulseMetadata: metadata)
        let ChainAbstractionNamespace = ChainAbstractionNamespace(chainAbstractionClient: chainAbstractionClient)

        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            chainAbstractionClient: chainAbstractionClient,
            ChainAbstractionNamespace: ChainAbstractionNamespace
        )
    }
}
