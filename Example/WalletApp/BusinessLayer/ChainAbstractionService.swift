import ReownWalletKit
import Foundation
import Web3

class ChainAbstractionService {
    enum NetworkError: Error {
        case invalidURL
        case invalidResponse
        case invalidData
    }

    let privateKey: EthereumPrivateKey

    init(privateKey: EthereumPrivateKey) {
        self.privateKey = privateKey
    }

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

                var transactions: [(transaction: EthereumSignedTransaction, chainId: String)] = []

                for tx in routeResponseAvailable.transactions {
                    do {
                        let estimates = try await WalletKit.instance.estimateFees(chainId: tx.chainId)
                        let maxPriorityFeePerGas = EthereumQuantity(quantity: try BigUInt(estimates.maxPriorityFeePerGas))
                        let maxFeePerGas = EthereumQuantity(quantity: try BigUInt(estimates.maxFeePerGas))

                        let transaction = try EthereumTransaction(
                            routingTransaction: tx,
                            maxPriorityFeePerGas: maxPriorityFeePerGas,
                            maxFeePerGas: maxFeePerGas
                        )

                        let chain = Blockchain(tx.chainId)!
                        let chainId = EthereumQuantity(quantity: BigUInt(chain.reference, radix: 10)!)

                        print(chainId.quantity)
                        let signedTransaction = try transaction.sign(with: privateKey, chainId: chainId)

                        print(signedTransaction.value)
                        transactions.append((transaction: signedTransaction, chainId: chain.absoluteString))
                    } catch {
                        print("Error processing transaction: \(error)")
                    }
                }

                try await broadcastTransactions(transactions: transactions)


            case .notRequired(let routeResponseNotRequired):
                print(("routing not required"))
            }
            print(tx)
        } catch {
            print(error)
        }
    }

    private func broadcastTransactions(transactions: [(transaction: EthereumSignedTransaction, chainId: String)]) async throws {
        for transaction in transactions {
            let chainId = transaction.chainId
            let projectId = Networking.projectId
            let rpcUrl = "rpc.walletconnect.com/v1?chainId=\(chainId)&projectId=\(projectId)"

            let rawTransaction = try transaction.transaction.rawTransaction()
            let rpcRequest = RPCRequest(method: "eth_sendRawTransaction", params: [rawTransaction])

            // Create URL and request
            guard let url = URL(string: "https://" + rpcUrl) else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Convert RPC request to JSON data
            let jsonData = try JSONEncoder().encode(rpcRequest)
            request.httpBody = jsonData

            do {
                // Use async/await URLSession
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.invalidResponse
                }

                // Parse response
                let responseJSON = try JSONSerialization.jsonObject(with: data)
                print("Transaction broadcast success: \(responseJSON)")

            } catch {
                print("Error broadcasting transaction: \(error)")
                throw error
            }
        }
    }
}



extension EthereumTransaction {
    init(routingTransaction: RoutingTransaction, maxPriorityFeePerGas: EthereumQuantity, maxFeePerGas: EthereumQuantity) throws {

        self.init(
            nonce: EthereumQuantity(quantity: BigUInt(routingTransaction.nonce.stripHexPrefix(), radix: 16)!),
            gasPrice: nil, // Not needed for EIP1559
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: EthereumQuantity(quantity: BigUInt(routingTransaction.gas.stripHexPrefix(), radix: 16)!),
            from: try EthereumAddress(hex: routingTransaction.from, eip55: false),
            to: try EthereumAddress(hex: routingTransaction.to, eip55: false),
            value: EthereumQuantity(quantity: 0.gwei),
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

fileprivate extension String {
    func stripHexPrefix() -> String {
        return hasPrefix("0x") ? String(dropFirst(2)) : self
    }
}
