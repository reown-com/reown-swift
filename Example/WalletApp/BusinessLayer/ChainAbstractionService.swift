import ReownWalletKit
import Foundation
import Web3

class ChainAbstractionService {
    enum Errors: LocalizedError {
        case invalidURL
        case invalidResponse
        case invalidData
        case transactionFailed(String) // Includes additional context about the transaction failure
        case receiptUnavailable(String) // Includes additional context when a receipt is not available

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The provided URL is invalid."
            case .invalidResponse:
                return "The server responded with an invalid response."
            case .invalidData:
                return "The data received from the server is invalid."
            case .transactionFailed(let reason):
                return "Transaction failed: \(reason)"
            case .receiptUnavailable(let transactionHash):
                return "Transaction receipt is unavailable for transaction hash: \(transactionHash)."
            }
        }
    }

    let privateKey: EthereumPrivateKey
    private let routeResponseAvailable: RouteResponseAvailable

    init(privateKey: EthereumPrivateKey, routeResponseAvailable: RouteResponseAvailable) {
        self.privateKey = privateKey
        self.routeResponseAvailable = routeResponseAvailable
    }

    func signTransactions() async throws -> [(transaction: EthereumSignedTransaction, chainId: String)] {
        var signedTransactions: [(transaction: EthereumSignedTransaction, chainId: String)] = []

        for tx in routeResponseAvailable.transactions {
            do {
                let estimates = try await WalletKit.instance.estimateFees(chainId: tx.chainId)
                let maxPriorityFeePerGas = EthereumQuantity(quantity: BigUInt(estimates.maxPriorityFeePerGas, radix: 10)! * 2)
                let maxFeePerGas = EthereumQuantity(quantity: BigUInt(estimates.maxFeePerGas, radix: 10)! * 2)

                print(maxFeePerGas)
                print(maxPriorityFeePerGas)
                let transaction = try EthereumTransaction(
                    routingTransaction: tx,
                    maxPriorityFeePerGas: maxPriorityFeePerGas,
                    maxFeePerGas: maxFeePerGas
                )
                prettyPrintTransaction(transaction)

                let chain = Blockchain(tx.chainId)!
                let chainId = EthereumQuantity(quantity: BigUInt(chain.reference, radix: 10)!)

                print(chainId.quantity)
                let signedTransaction = try transaction.sign(with: privateKey, chainId: chainId)

                print(signedTransaction.value)
                print("nonce: \(signedTransaction.nonce)")
                signedTransactions.append((transaction: signedTransaction, chainId: chain.absoluteString))
            } catch {
                print("Error processing transaction: \(error)")
            }
        }
        return signedTransactions
    }

    private func getRpcUrl(chainId: String) -> String {
//                    let projectId = Networking.projectId
//
//        return "https://rpc.walletconnect.com/v1?chainId=\(chainId)&projectId=\(projectId)"

        switch chainId {
        case "eip155:10":
            return "https://mainnet.optimism.io"
        case "eip155:8453":
            return "https://mainnet.base.org"
        case "eip155:42161":
            return "https://arbitrum.llamarpc.com"
        default:
            let projectId = Networking.projectId
            return "https://rpc.walletconnect.com/v1?chainId=\(chainId)&projectId=\(projectId)"
        }
    }


    func broadcastTransactions(transactions: [(transaction: EthereumSignedTransaction, chainId: String)]) async throws -> [(txHash: String, chainId: String)] {
        var transactionResults: [(txHash: String, chainId: String)] = []

        // do it in series
        for transaction in transactions {
            let chainId = transaction.chainId
            let rpcUrl = getRpcUrl(chainId: chainId)

            // Build the raw transaction
            let rawTransaction = try transaction.transaction.rawTransaction()
            let rpcRequest = RPCRequest(method: "eth_sendRawTransaction", params: [rawTransaction])

            // Create URL and request
            guard let url = URL(string: rpcUrl) else {
                throw Errors.invalidURL
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
                    throw Errors.invalidResponse
                }

                // Parse JSON response to extract the transaction hash
                // Parse JSON response to extract the transaction hash
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 Full JSON response: \(json)") // Print the full JSON response
                    if let transactionHash = json["result"] as? String {
                        transactionResults.append((txHash: transactionHash, chainId: chainId))
                        print("Transaction broadcast success: \(transactionHash) on chain \(chainId)")
                    } else {
                        throw Errors.invalidData
                    }
                } else {
                    throw Errors.invalidData
                }

            } catch {
                print("Error broadcasting transaction on chain \(chainId): \(error)")
                throw error
            }
        }

        return transactionResults
    }

    func getTransactionReceipt(transactionHash: String, chainId: String, retries: Int = 10, delay: UInt64 = 2_000_000_000) async throws -> [String: Any] {
        let rpcUrl = getRpcUrl(chainId: chainId)

        // Build the RPC request
        let rpcRequest = RPCRequest(method: "eth_getTransactionReceipt", params: [transactionHash])

        guard let url = URL(string: rpcUrl) else {
            throw Errors.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert RPC request to JSON data
        let jsonData = try JSONEncoder().encode(rpcRequest)
        request.httpBody = jsonData

        for attempt in 1...retries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw Errors.invalidResponse
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 Full JSON response: \(json)") // Print the full JSON response
                    if let result = json["result"] as? [String: Any] {
                        // Receipt is available
                        return result
                    } else {
                        // Receipt is still pending
                        print("⏳ Receipt not available for \(transactionHash) on chain \(chainId). Attempt \(attempt) of \(retries). Retrying...")
                    }
                } else {
                    throw Errors.invalidData
                }
            } catch {
                print("❌ Error fetching transaction receipt for \(transactionHash) on chain \(chainId): \(error)")
                throw error
            }

            if attempt < retries {
                try await Task.sleep(nanoseconds: delay)
            }
        }

        // If no receipt is returned after retries
        throw Errors.invalidData
    }

    private func prettyPrintTransaction(_ transaction: EthereumTransaction) {
        func formatQuantity(_ quantity: EthereumQuantity?) -> String {
            guard let quantity = quantity else { return "nil" }
            return String(quantity.quantity)
        }

        print("""
        Ethereum Transaction:
        ----------------------
        Nonce: \(formatQuantity(transaction.nonce))
        Gas Price: \(formatQuantity(transaction.gasPrice))
        Max Fee Per Gas: \(formatQuantity(transaction.maxFeePerGas))
        Max Priority Fee Per Gas: \(formatQuantity(transaction.maxPriorityFeePerGas))
        Gas Limit: \(formatQuantity(transaction.gasLimit))
        From: \(transaction.from?.hex(eip55: true) ?? "nil")
        To: \(transaction.to?.hex(eip55: true) ?? "nil")
        Value: \(formatQuantity(transaction.value))
        Data: \(transaction.data.bytes.map { String(format: "%02x", $0) }.joined())
        Access List: \(transaction.accessList)
        Transaction Type: \(transaction.transactionType)
        ----------------------
        """)
    }
}



extension EthereumTransaction {
    init(routingTransaction: Transaction, maxPriorityFeePerGas: EthereumQuantity, maxFeePerGas: EthereumQuantity) throws {

        self.init(
            nonce: EthereumQuantity(quantity: BigUInt(routingTransaction.nonce.stripHexPrefix(), radix: 10)!),
            gasPrice: nil, // Not needed for EIP1559
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: EthereumQuantity(quantity: BigUInt(routingTransaction.gas.stripHexPrefix(), radix: 10)!),
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


