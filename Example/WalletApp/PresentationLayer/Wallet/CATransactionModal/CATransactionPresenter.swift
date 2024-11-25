import UIKit
import Combine
import Web3
import ReownWalletKit

final class CATransactionPresenter: ObservableObject {
    enum Errors: Error {
        case invalidURL
        case invalidResponse
        case invalidData
    }
    // Published properties to be used in the view
    @Published var payingAmount: Double = 10.00
    @Published var balanceAmount: Double = 5.00
    @Published var bridgingAmount: Double = 5.00
    @Published var appURL: String = ""
    @Published var networkName: String = ""
    @Published var estimatedFees: Double = 4.34
    @Published var bridgeFee: Double = 3.00
    @Published var purchaseFee: Double = 1.34
    @Published var executionSpeed: String = "Fast (~20 sec)"

    private let sessionRequest: Request
    private let routeResponseAvailable: RouteResponseAvailable
    let chainAbstractionService: ChainAbstractionService!
    var fundingFrom: [FundingMetadata] {
        return routeResponseAvailable.metadata.fundingFrom
    }
    let router: CATransactionRouter
    let importAccount: ImportAccount

    private var disposeBag = Set<AnyCancellable>()

    init(
        sessionRequest: Request,
        importAccount: ImportAccount,
        routeResponseAvailable: RouteResponseAvailable,
        router: CATransactionRouter
    ) {
        self.sessionRequest = sessionRequest
        self.routeResponseAvailable = routeResponseAvailable
        let prvKey = try! EthereumPrivateKey(hexPrivateKey: importAccount.privateKey)
        self.chainAbstractionService = ChainAbstractionService(privateKey: prvKey, routeResponseAvailable: routeResponseAvailable)
        self.router = router
        self.importAccount = importAccount
        // Any additional setup for the parameters
        setupInitialState()
    }

    func dismiss() {
        // Implement dismissal logic if needed
    }

    func approveTransactions() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()
                let signedTransactions = try await chainAbstractionService.signTransactions()

                print(signedTransactions[0])
                try await chainAbstractionService.broadcastTransactions(transactions: signedTransactions)
                let orchestrationId = routeResponseAvailable.orchestrationId
                //                let statusResponseCompleted = try await WalletKit.instance.waitForSuccess(orchestrationId: orchestrationId, checkIn: routeResponseAvailable.metadata.checkIn)


                var status: StatusResponse = try await WalletKit.instance.status(orchestrationId: orchestrationId)
                loop: while true {
                    switch status {
                    case .pending(let pending):
                        let delay = try UInt64(pending.checkIn) * 1_000_000
                        try await Task.sleep(nanoseconds: delay)
                        // Fetch the status again after the delay
                        status = try await WalletKit.instance.status(orchestrationId: orchestrationId)
                    case .completed(let completed):
                        // Handle the completed status
                        print("Transaction completed: \(completed)")
                        AlertPresenter.present(message: "routing transactions completed", type: .success)
                        break loop // Exit the labeled loop but continue with the function
                    case .error(let error):
                        // Handle the error
                        print("Transaction failed: \(error)")
                        AlertPresenter.present(message: "routing failed with error: \(error)", type: .error)
                        ActivityIndicatorManager.shared.stop()
                        return // Exit the function due to an error
                    }
                }

                try await sendInitialTransaction()
                ActivityIndicatorManager.shared.stop()

                // broadcast initial transaction
            } catch {
                AlertPresenter.present(message: error.localizedDescription, type: .error)
            }
        }
    }

    private func sendInitialTransaction() async throws {
        struct Tx: Codable {
            let data: String
            let from: String
            let to: String
        }

        print("will send initial transaction")
        let tx = try! sessionRequest.params.get([Tx].self)[0]



        let estimates = try await WalletKit.instance.estimateFees(chainId: sessionRequest.chainId.absoluteString)

        let maxPriorityFeePerGas = EthereumQuantity(quantity: BigUInt(estimates.maxPriorityFeePerGas, radix: 10)!)
        let maxFeePerGas = EthereumQuantity(quantity: BigUInt(estimates.maxFeePerGas, radix: 10)!)
        let from = try EthereumAddress(hex: tx.from, eip55: false)

        let nonce = try await getNonce(for: from, chainId: sessionRequest.chainId.absoluteString)

        let ethTransaction = EthereumTransaction(
            nonce: nonce,
            gasPrice: nil,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: EthereumQuantity(quantity: 1023618),
            from: from,
            to: try EthereumAddress(hex: tx.to, eip55: false),
            value: EthereumQuantity(quantity: 0.gwei),
            data: EthereumData(Array(hex: tx.data)),
            accessList: [:],
            transactionType: .eip1559)

        let chain = sessionRequest.chainId
        let chainId = EthereumQuantity(quantity: BigUInt(chain.reference, radix: 10)!)

        let privateKey = try EthereumPrivateKey(hexPrivateKey: importAccount.privateKey)

        let signedTransaction = try ethTransaction.sign(with: privateKey, chainId: chainId)

        try await chainAbstractionService.broadcastTransactions(transactions: [(signedTransaction, chain.absoluteString)])

    }

    func getNonce(for address: EthereumAddress, chainId: String) async throws -> EthereumQuantity {
        // Create a Web3 provider

        print("Getting nonce for initial transaction...")
        let projectId = Networking.projectId
        let rpcUrl = "rpc.walletconnect.com/v1?chainId=\(chainId)&projectId=\(projectId)"

        let params = [address.hex(eip55: true), "latest"]

        let rpcRequest = RPCRequest(method: "eth_getTransactionCount", params: params)

        guard let url = URL(string: "https://" + rpcUrl) else {
            throw Errors.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert RPC request to JSON data
        let jsonData = try JSONEncoder().encode(rpcRequest)
        request.httpBody = jsonData

        do {
            // Perform the URL session request
            let (data, response) = try await URLSession.shared.data(for: request)

            // Validate the response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw Errors.invalidResponse
            }

            let rpcResponse = try JSONDecoder().decode(RPCResponse.self, from: data)

            let responseJSON = try JSONSerialization.jsonObject(with: data)
            print(responseJSON)

            let stringResult = try rpcResponse.result!.get(String.self)
            guard let nonceValue = BigUInt(stringResult.stripHexPrefix(), radix: 16) else {
                throw Errors.invalidData
            }

            return EthereumQuantity(quantity: nonceValue)
        } catch {
            print("Error fetching nonce: \(error)")
            throw error
        }
    }

    @MainActor
    func rejectTransactions() async throws {
        do {
            ActivityIndicatorManager.shared.start()
            try await WalletKit.instance.respond(
                topic: sessionRequest.topic,
                requestId: sessionRequest.id,
                response: .error(.init(code: 0, message: ""))
            )
            ActivityIndicatorManager.shared.stop()
            router.dismiss()
        } catch {
            ActivityIndicatorManager.shared.stop()
            AlertPresenter.present(message: error.localizedDescription, type: .error)
            //            errorMessage = error.localizedDescription
            //            showError.toggle()
        }
    }

    func network(for chainId: String) -> String {
        let chainIdToNetwork = [
            "eip155:10": "Optimism",
            "eip155:42161": "Arbitrium",
            "eip155:8453": "Base"
        ]
        return chainIdToNetwork[chainId]!
    }

    func hexAmountToDenominatedUSDC(_ hexAmount: String) -> String {
        guard let indecValue = hexToDecimal(hexAmount) else {
            return "Invalid amount"
        }
        let usdcValue = Double(indecValue) / 1_000_000
        return String(format: "%.2f", usdcValue)
    }

    func hexToDecimal(_ hex: String) -> Int? {
        let cleanHex = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex

        return Int(cleanHex, radix: 16)
    }

    func setupInitialState() {
        if let session = WalletKit.instance.getSessions().first(where: { $0.topic == sessionRequest.topic }) {
            self.appURL = session.peer.url
        }
        networkName = network(for: sessionRequest.chainId.absoluteString)
    }
}

// MARK: - SceneViewModel
extension CATransactionPresenter: SceneViewModel {}
