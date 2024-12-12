import UIKit
import Combine
import Web3
import ReownWalletKit

final class CATransactionPresenter: ObservableObject {
    enum Errors: LocalizedError {
        case invalidURL
        case invalidResponse
        case invalidData
    }
    // Published properties to be used in the view
    @Published var payingAmount: String = ""
    @Published var balanceAmount: String = ""
    @Published var appURL: String = ""
    @Published var networkName: String!
    @Published var estimatedFees: String = ""
    @Published var bridgeFee: String = ""
    @Published var executionSpeed: String = "Fast (~20 sec)"
    @Published var transactionCompleted: Bool = false
    @Published var fundingFromNetwork: String!


    private let sessionRequest: Request
    private let routeResponseAvailable: RouteResponseAvailable
    let chainAbstractionService: ChainAbstractionService!
    var fundingFrom: [FundingMetadata] {
        return routeResponseAvailable.metadata.fundingFrom
    }
    var initialTransactionMetadata: InitialTransactionMetadata {
        return routeResponseAvailable.metadata.initialTransaction
    }
    let router: CATransactionRouter
    let importAccount: ImportAccount
    var routeUiFields: RouteUiFields? = nil
    var chainId: String {
        sessionRequest.chainId.absoluteString
    }

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
        self.networkName = network(for: sessionRequest.chainId.absoluteString)
        self.fundingFromNetwork = network(for: fundingFrom[0].chainId)
        // Any additional setup for the parameters
        setupInitialState()
    }

    func dismiss() {
        router.dismiss()
    }

    func approveTransactions() async throws {
        do {
            print("🚀 Starting transaction approval process...")
            ActivityIndicatorManager.shared.start()

            print("📝 Signing transactions...")
            let signedTransactions = try await chainAbstractionService.signTransactions()
            print("✅ Successfully signed transactions. First transaction: \(signedTransactions[0])")

            print("📡 Broadcasting signed transactions...")
            let txResults = try await chainAbstractionService.broadcastTransactions(transactions: signedTransactions)

            print("🧾 Fetching transaction receipts...")
            for (txHash, chainId) in txResults {
                do {
                    let receipt = try await chainAbstractionService.getTransactionReceipt(transactionHash: txHash, chainId: chainId)
                    print("✅ Transaction receipt for \(txHash) on chain \(chainId): \(receipt)")

                } catch {
                    print("❌ Failed to fetch receipt for \(txHash) on chain \(chainId): \(error)")
                    throw error
                }
            }

            let orchestrationId = routeResponseAvailable.orchestrationId
            print("📋 Orchestration ID: \(orchestrationId)")

            print("🔄 Starting status check loop...")
            var status: StatusResponse = try await WalletKit.instance.status(orchestrationId: orchestrationId)

            loop: while true {
                switch status {
                case .pending(let pending):
                    print("⏳ Transaction pending. Waiting for \(pending.checkIn) seconds...")
                    let delay = try UInt64(pending.checkIn) * 1_000_000
                    try await Task.sleep(nanoseconds: delay)
                    print("🔍 Checking status again...")
                    status = try await WalletKit.instance.status(orchestrationId: orchestrationId)

                case .completed(let completed):
                    print("✅ Transaction completed successfully!")
                    print("📊 Completion details: \(completed)")
                    AlertPresenter.present(message: "Routing transactions completed", type: .success)
                    break loop

                case .error(let error):
                    print("❌ Transaction failed with error!")
                    print("💥 Error details: \(error)")
                    AlertPresenter.present(message: "Routing failed with error: \(error)", type: .error)
                    ActivityIndicatorManager.shared.stop()
                    return
                }
            }

            print("🚀 Initiating initial transaction...")
            try await sendInitialTransaction()
            ActivityIndicatorManager.shared.stop()
            print("✅ Initial transaction process completed successfully")
            AlertPresenter.present(message: "Initial transaction sent", type: .success)

        } catch {
            print("❌ Transaction approval failed!")
            print("💥 Error details: \(error.localizedDescription)")
            AlertPresenter.present(message: error.localizedDescription, type: .error)
            throw error
        }
    }

    private func sendInitialTransaction() async throws {

        print("📝 Preparing initial transaction...")
        let tx = try! sessionRequest.params.get([Tx].self)[0]
        print("📊 Transaction details:")
        print("   From: \(tx.from)")
        print("   To: \(tx.to)")
        print("   Data length: \(tx.data.count) characters")

        print("💰 Estimating fees...")
        let estimates = try await WalletKit.instance.estimateFees(chainId: sessionRequest.chainId.absoluteString)
        print("📊 Fee estimates:")
        print("   Max Priority Fee: \(estimates.maxPriorityFeePerGas)")
        print("   Max Fee: \(estimates.maxFeePerGas)")

        let maxPriorityFeePerGas = EthereumQuantity(quantity: BigUInt(estimates.maxPriorityFeePerGas, radix: 10)!)
        let maxFeePerGas = EthereumQuantity(quantity: BigUInt(estimates.maxFeePerGas, radix: 10)!)
        let from = try EthereumAddress(hex: tx.from, eip55: false)

        print("🔢 Fetching nonce...")
        let nonce = try await getNonce(for: from, chainId: sessionRequest.chainId.absoluteString)
        print("✅ Retrieved nonce: \(nonce)")

        print("🔧 Building Ethereum transaction...")
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
        print("⛓️ Using chain ID: \(chainId)")

        print("🔑 Signing transaction with private key...")
        let privateKey = try EthereumPrivateKey(hexPrivateKey: importAccount.privateKey)
        let signedTransaction = try ethTransaction.sign(with: privateKey, chainId: chainId)
        print("✅ Transaction signed successfully")

        print("📡 Broadcasting initial transaction...")
        try await chainAbstractionService.broadcastTransactions(transactions: [(signedTransaction, chain.absoluteString)])
        print("✅ Initial transaction broadcast complete")

        let result = signedTransaction.r.hex() + signedTransaction.s.hex().dropFirst(2) + String(signedTransaction.v.quantity, radix: 16)

        try await WalletKit.instance.respond(topic: sessionRequest.topic, requestId: sessionRequest.id, response: .response(AnyCodable(result)))

        DispatchQueue.main.async { [weak self] in
            self?.transactionCompleted = true
        }
    }

    func getNonce(for address: EthereumAddress, chainId: String) async throws -> EthereumQuantity {
        print("🔢 Getting nonce for address: \(address.hex(eip55: true))")
        print("⛓️ Chain ID: \(chainId)")

        let projectId = Networking.projectId
        let rpcUrl = "rpc.walletconnect.com/v1?chainId=\(chainId)&projectId=\(projectId)"
        print("🌐 Using RPC URL: \(rpcUrl)")

        let params = [address.hex(eip55: true), "latest"]
        let rpcRequest = RPCRequest(method: "eth_getTransactionCount", params: params)
        print("📝 Created RPC request for nonce")

        guard let url = URL(string: "https://" + rpcUrl) else {
            print("❌ Failed to create URL from RPC URL string")
            throw Errors.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert RPC request to JSON data
        let jsonData = try JSONEncoder().encode(rpcRequest)
        request.httpBody = jsonData

        do {
            print("📡 Sending request to get nonce...")
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type received")
                throw Errors.invalidResponse
            }

            print("📊 Response status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Received error status code: \(httpResponse.statusCode)")
                throw Errors.invalidResponse
            }

            let rpcResponse = try JSONDecoder().decode(RPCResponse.self, from: data)
            let responseJSON = try JSONSerialization.jsonObject(with: data)
            print("📥 Raw response: \(responseJSON)")

            let stringResult = try rpcResponse.result!.get(String.self)
            print("🔢 Nonce hex string: \(stringResult)")

            guard let nonceValue = BigUInt(stringResult.stripHexPrefix(), radix: 16) else {
                print("❌ Failed to parse nonce value from hex string")
                throw Errors.invalidData
            }

            print("✅ Successfully retrieved nonce: \(nonceValue)")
            return EthereumQuantity(quantity: nonceValue)
        } catch {
            print("❌ Error while fetching nonce:")
            print("💥 Error details: \(error)")
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
        Task { try await setUpRoutUiFields() }
        payingAmount = initialTransactionMetadata.amount

        let tx = try! sessionRequest.params.get([Tx].self)[0]

        Task {
            let balance = try await WalletKit.instance.erc20Balance(chainId: chainId, token: tx.to, owner: importAccount.account.address)
            await MainActor.run {
                balanceAmount = balance
            }
        }
    }

    

    func setUpRoutUiFields() async throws {
        struct Tx: Codable {
            let data: String
            let from: String
            let to: String
        }
        let tx = try! sessionRequest.params.get([Tx].self)[0]

        let estimates = try await WalletKit.instance.estimateFees(chainId: chainId)

        let initTx = Transaction(
            from: tx.from,
            to: tx.to,
            value: "0",
            gas: "0",
            data: tx.data,
            nonce: "0x",
            chainId: sessionRequest.chainId.absoluteString,
            gasPrice: "0",
            maxFeePerGas: estimates.maxFeePerGas,
            maxPriorityFeePerGas: estimates.maxPriorityFeePerGas
        )
        let routUiFields = try await WalletKit.instance.getRouteUiFieds(routeResponse: routeResponseAvailable, initialTransaction: initTx, currency: Currency.usd)
        print("aaaaaaaa")

        print(routUiFields.localTotal)
        print("bbbbbb")

        print(routUiFields.localTotal.formatted)
        print("XXXXXXXXX")
        print(routUiFields.localTotal.formattedAlt)

        await MainActor.run {

            estimatedFees = routUiFields.localTotal.formattedAlt
            bridgeFee = routUiFields.bridge.first!.localFee.formattedAlt
        }

    }

    func onViewOnExplorer() {
        // Force unwrap the address from the import account
        let address = importAccount.account.address

        // Mapping of network names to Blockscout URLs
        let networkBaseURLMap: [String: String] = [
            "Optimism": "optimism.blockscout.com",
            "Arbitrium": "arbitrum.blockscout.com",
            "Base": "base.blockscout.com"
        ]

        // Force unwrap the base URL for the current network
        let baseURL = networkBaseURLMap[networkName]!

        // Construct the explorer URL
        let explorerURL = URL(string: "https://\(baseURL)/address/\(address)")!

        // Open the URL in Safari
        UIApplication.shared.open(explorerURL, options: [:], completionHandler: nil)

        print("🌐 Opened explorer URL: \(explorerURL)")
    }
}

// MARK: - SceneViewModel
extension CATransactionPresenter: SceneViewModel {}

