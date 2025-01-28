import Foundation
import YttriumWrapper

/// A manager that creates or retrieves a GasAbstractionClient
/// for a given eoa Account.
class GasAbstractionClientsManager {
    private var EOAToClient: [Account: Client] = [:]
    private let apiKey: String

    init(pimlicoApiKey: String) {
        self.apiKey = pimlicoApiKey
    }

    /// Returns an existing GasAbstractionClient for the given eoa Account,
    /// or creates a new one if none exists.
    func getOrCreateGasAbstractionClient(for EOA: Account) -> Client {
        if let existingClient = EOAToClient[EOA] {
            return existingClient
        } else {
            let newClient = createGasAbstractionClient(EOAAccount: EOA)
            EOAToClient[EOA] = newClient
            return newClient
        }
    }

#if DEBUG
    public func set7702ForLocalInfra(address: String) {
        let chainId = "eip155:11155111"

        let eoa = Account(blockchain: Blockchain(chainId)!, address: address)!
        let localRpcUrl = URL(string: "http://localhost:8545")!
        let localBundlerUrl = URL(string: "http://localhost:4337")!
        let localPaymasterUrl = URL(string: "http://localhost:3000")!

        let gasAbstractionClient = getOrCreateGasAbstractionClient(for: eoa)


        let newClient = gasAbstractionClient
            .withRpcOverrides(rpcOverrides: [chainId: localRpcUrl.absoluteString])
            .with4337Urls(
                bundlerUrl: localBundlerUrl.absoluteString,
                paymasterUrl: localPaymasterUrl.absoluteString
            )

        EOAToClient[eoa] = newClient

    }
#endif

    private func createGasAbstractionClient(EOAAccount: Account) -> Client {
//        let chainId = EOAAccount.reference
        let projectId = Networking.projectId
//        let pimlicoBundlerUrl = "https://api.pimlico.io/v2/\(chainId)/rpc?apikey=\(apiKey)"
//        let rpcUrl = "https://rpc.walletconnect.com/v1?chainId=\(EOAAccount.blockchainIdentifier)&projectId=\(projectId)"

        // Adjust config as needed, similarly to how you do for SafesManager
//        let config = Config(
//            endpoints: .init(
//                rpc: .init(baseUrl: rpcUrl, apiKey: ""),
//                bundler: .init(baseUrl: pimlicoBundlerUrl, apiKey: ""),
//                paymaster: .init(baseUrl: pimlicoBundlerUrl, apiKey: "")
//            )
//        )


        // Replace this initializer with however you construct a GasAbstractionClient
        let client = Client(projectId: projectId)

        return client
    }
}
