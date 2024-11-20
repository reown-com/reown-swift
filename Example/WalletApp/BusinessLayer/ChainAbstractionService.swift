import ReownWalletKit
import Foundation
import Web3

class ChainAbstractionService {

    let privateKey: EthereumPrivateKey!

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

            let transaction = EthTransaction(
                from: tx.from,
                to: tx.to,
                value: "0",
                gas: "0",
                gasPrice: "0",
                data: tx.data,
                nonce: "0",
                maxFeePerGas: "0",
                maxPriorityFeePerGas: "0",
                chainId: request.chainId.absoluteString
            )

            let routeResponseSuccess = try await WalletKit.instance.route(transaction: transaction)

            switch routeResponseSuccess {

            case .available(let routeResponseAvailable):


                var transactions: [(transaction: EthereumSignedTransaction, chainId: String)]
                routeResponseAvailable.transactions.forEach { tx in

                    let estimates = try await WalletKit.instance.estimateFees(chainId: tx.chainId)
                    let maxPriorityFeePerGas = EthereumQuantity(quantity: try! BigUInt(estimates.maxPriorityFeePerGas))
                    let maxFeePerGas = EthereumQuantity(quantity: try! BigUInt(estimates.maxFeePerGas))

                    let transaction = try! EthereumTransaction(
                        routingTransaction: tx,
                        maxPriorityFeePerGas: maxPriorityFeePerGas,
                        maxFeePerGas: maxFeePerGas
                    )

                    let chain = Blockchain(tx.chainId)!
                    let chainId = EthereumQuantity(quantity: BigUInt(chain.reference))

                    let signedTransaction = try transaction.sign(with: privateKey, chainId: chainId)

                    transactions.append((transaction: signedTransaction, chainId: chain.absoluteString))
                }


            case .notRequired(let routeResponseNotRequired):
                print(("routing not required"))
            }
            print(tx)
        } catch {
            print(error)
        }
    }
}



extension EthereumTransaction {
    init(routingTransaction: RoutingTransaction, maxPriorityFeePerGas: EthereumQuantity, maxFeePerGas: EthereumQuantity) throws {

        self.init(
            nonce: try EthereumQuantity(routingTransaction.nonce),
            gasPrice: nil, // Not needed for EIP1559
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: try EthereumQuantity(routingTransaction.gas),
            from: try EthereumAddress(hex: routingTransaction.from, eip55: false),
            to: try EthereumAddress(hex: routingTransaction.to, eip55: false),
            value: try EthereumQuantity(routingTransaction.value),
            data: EthereumData(Array(hex: routingTransaction.data)),
            accessList: [:], // Empty access list for basic transactions
            transactionType: .eip1559 // Specify EIP1559 transaction type
        )
    }

    enum InitializationError: Error {
        case invalidAddress(String)
        case invalidValue(String)
    }
}
