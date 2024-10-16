
import Foundation

class SafesManager {
    var ownerToClient: [Account: AccountClient] = [:]
    let rpcUrl: String
    let apiKey: String

    init(pimlicoApiKey: String, rpcUrl: String) {
        self.apiKey = pimlicoApiKey
        self.rpcUrl = rpcUrl
    }

    func getOrCreateSafe(for owner: Account) -> AccountClient {
        if let client = ownerToClient[owner] {
            return client
        } else {
            // to do check if chain is supported
            let safe = createSafe(ownerAccount: owner)
            ownerToClient[owner] = safe
            return safe
        }
    }

    private func createSafe(ownerAccount: Account) -> AccountClient {
        let chainId = ownerAccount.reference
        let pimlicoBundlerUrl = "https://api.pimlico.io/v2/\(chainId)/rpc?apikey=\(apiKey)"
        let rpcUrl = "https://\(rpcUrl)"
        let pimlicoSepolia = YttriumWrapper.Config(
            endpoints: .init(
                rpc: .init(baseURL: rpcUrl),
                bundler: .init(baseURL: pimlicoBundlerUrl),
                paymaster: .init(baseURL: pimlicoBundlerUrl)
            )
        )
        // use YttriumWrapper.Config.local() for local foundry node
        return AccountClient(
            ownerAddress: ownerAccount.address,
            entryPoint: "", // remove the entrypoint
            chainId: Int(ownerAccount.blockchain.reference)!,
            config: pimlicoSepolia,
            safe: true
        )
    }
}
