
import Foundation

class SafesManager {
    var ownerToClient: [Account: AccountClient] = [:]
    let entryPoint = "0x0000000071727De22E5E9d8BAf0edAc6f37da032" // v0.7 on Sepolia
    let rpcUrl: String
    let bundlerUrl: String

    init(bundlerUrl: String, rpcUrl: String) {
        self.bundlerUrl = bundlerUrl
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

        let pimlicoBundlerUrl = "https://\(bundlerUrl)"
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
            entryPoint: entryPoint,
            chainId: Int(ownerAccount.blockchain.reference)!,
            config: pimlicoSepolia,
            safe: true
        )
    }
}
