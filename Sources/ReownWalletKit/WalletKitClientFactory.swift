import Foundation

public struct WalletKitClientFactory {
    public static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol
    ) -> WalletKitClient {
        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient
        )
    }
}
