import Foundation
#if SWIFT_PACKAGE
import WalletConnectPay
#endif
// import YttriumWrapper

struct WalletKitClientFactory {
    static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol,
        config: WalletKit.Config,
        projectId: String? = nil
    ) -> WalletKitClient {
        // Chain abstraction client creation commented out
        /*
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
        */

        // Create Pay namespace wrapping the already-configured PayClient
        let payNamespace = PayNamespace(payClient: WalletConnectPay.instance)

        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            payNamespace: payNamespace
            // chainAbstractionClient: chainAbstractionClient,
            // ChainAbstractionNamespace: ChainAbstractionNamespace
        )
    }
}
