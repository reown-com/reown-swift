
import Foundation
import YttriumWrapper

class SafesManager {
    var ownerToClient: [Account: AccountClient] = [:]
    let apiKey: String

    init(pimlicoApiKey: String) {
        self.apiKey = pimlicoApiKey
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
        let projectId = Networking.projectId
        let pimlicoBundlerUrl = "https://api.pimlico.io/v2/\(chainId)/rpc?apikey=\(apiKey)"
        let rpcUrl = "https://rpc.walletconnect.com/v1?chainId=\(ownerAccount.blockchainIdentifier)&projectId=\(projectId)"
        let pimlicoSepolia = YttriumWrapper.Config(
            endpoints: .init(
                rpc: .init(baseURL: rpcUrl),
                bundler: .init(baseURL: pimlicoBundlerUrl),
                paymaster: .init(baseURL: pimlicoBundlerUrl)
            )
        )
        // use YttriumWrapper.Config.local() for local foundry node
        let x =  AccountClient(
            ownerAddress: ownerAccount.address,
            entryPoint: "", // remove the entrypoint
            chainId: Int(ownerAccount.blockchain.reference)!,
            config: pimlicoSepolia,
            safe: true
        )
        // TODO remove registration
        x.register(privateKey: "ff89825a799afce0d5deaa079cdde227072ec3f62973951683ac8cc033092156")
        return x
    }
}
