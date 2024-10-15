import Foundation

struct WalletKitClientFactory {
    static func create(
        signClient: SignClientProtocol,
        pairingClient: PairingClientProtocol,
        pushClient: PushClientProtocol,
        config: WalletKit.Config
    ) -> WalletKitClient {
        var safesManager: SafesManager? = nil
        if let bundlerUrl = config.bundlerUrl,
           let rpcUrl = config.rpcUrl {
            safesManager = SafesManager(bundlerUrl: bundlerUrl, rpcUrl: rpcUrl)
        }
        return WalletKitClient(
            signClient: signClient,
            pairingClient: pairingClient,
            pushClient: pushClient,
            smartAccountsManager: safesManager
        )
    }
}
