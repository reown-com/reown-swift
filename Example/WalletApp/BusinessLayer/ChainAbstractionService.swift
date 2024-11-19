import ReownWalletKit
import Foundation

class ChainAbstractionService {

    func handle(request: Request) async throws {
        struct Tx: Codable {
            let data: String
            let from: String
            let to: String
        }


        guard request.method == "eth_sendTransaction" else {
            return
        }
        do {
            let tx = try request.params.get([Tx].self)[0]

            let transaction = EthTransaction(from: tx.from, to: tx.to, value: "0", gas: "0", gasPrice: "0", data: tx.data, nonce: "0", maxFeePerGas: "0", maxPriorityFeePerGas: "0", chainId: request.chainId.absoluteString)

            let x = try await WalletKit.instance.route(transaction: transaction)
            print(tx)
        } catch {
            print(error)
        }
    }
}
