import UIKit
import Combine
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

    private let sessionRequest: Request?
    var fundingFrom: [FundingMetadata] {
        return uiFields.routeResponse.metadata.fundingFrom
    }
    var initialTransactionMetadata: InitialTransactionMetadata {
        return uiFields.routeResponse.metadata.initialTransaction
    }
    let router: CATransactionRouter
    let importAccount: ImportAccount
    var uiFields: UiFields
    let call: Call
    var chainId: Blockchain
    let from: String

    private var disposeBag = Set<AnyCancellable>()

    init(
        sessionRequest: Request?,
        importAccount: ImportAccount,
        router: CATransactionRouter,
        call: Call,
        from: String,
        chainId: Blockchain,
        uiFields: UiFields
    ) {
        self.sessionRequest = sessionRequest
        self.router = router
        self.importAccount = importAccount
        self.chainId = chainId
        self.call = call
        self.from = from
        self.uiFields = uiFields
        self.networkName = network(for: chainId.absoluteString)
        self.fundingFromNetwork = network(for: fundingFrom[0].chainId)
        setupInitialState()
    }

    func dismiss() {
        router.dismiss()
    }

    func approveTransactions() async throws -> ExecuteDetails {
        do {
            print("🚀 Starting transaction approval process...")
            ActivityIndicatorManager.shared.start()

            let initialTxHash = uiFields.initial.transactionHashToSign

            var routeTxnSigs = [B256]()
            let signer = ETHSigner(importAccount: importAccount)

            print("📝 Signing route transactions...")
            for txnDetails in uiFields.route {
                let hash = txnDetails.transactionHashToSign
                let sig = try! signer.signHash(hash)
                routeTxnSigs.append(sig)
                print("🔑 Signed transaction hash: \(hash)")
            }

            let initialTxnSig = try! signer.signHash(initialTxHash)
            print("🔑 Signed initial transaction hash: \(initialTxHash)")

            print("📝 Executing transactions through WalletKit...")
            let executeDetails = try await WalletKit.instance.ChainAbstraction.execute(uiFields: uiFields, routeTxnSigs: routeTxnSigs, initialTxnSig: initialTxnSig)

            print("✅ Transaction approval process completed successfully.")
            AlertPresenter.present(message: "Transaction approved successfully", type: .success)
            if let sessionRequest = sessionRequest {
                try await WalletKit.instance.respond(topic: sessionRequest.topic, requestId: sessionRequest.id, response: .response(AnyCodable(executeDetails.initialTxnHash)))
            }
            ActivityIndicatorManager.shared.stop()
            await MainActor.run {
                transactionCompleted = true
            }
            return executeDetails
        } catch {
            print("❌ Transaction approval failed with error: \(error.localizedDescription)")
            ActivityIndicatorManager.shared.stop()
            throw error
        }
    }

    @MainActor
    func rejectTransactions() async throws {
        try await respondError()
    }

    func respondError() async throws {
        guard let sessionRequest = sessionRequest else { return }
        do {
            ActivityIndicatorManager.shared.start()
            try await WalletKit.instance.respond(
                topic: sessionRequest.topic,
                requestId: sessionRequest.id,
                response: .error(.init(code: 0, message: ""))
            )
            ActivityIndicatorManager.shared.stop()
            await MainActor.run {
                router.dismiss()
            }
        } catch {
            ActivityIndicatorManager.shared.stop()
            AlertPresenter.present(message: error.localizedDescription, type: .error)
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
        estimatedFees = uiFields.localTotal.formattedAlt
        bridgeFee = uiFields.bridge.first!.localFee.formattedAlt

        if let session = WalletKit.instance.getSessions().first(where: { $0.topic == sessionRequest?.topic }) {
            self.appURL = session.peer.url
        }
        networkName = network(for: chainId.absoluteString)
        payingAmount = initialTransactionMetadata.amount

        let tx = call
        Task {
            let balance = try await WalletKit.instance.erc20Balance(chainId: chainId.absoluteString, token: tx.to, owner: importAccount.account.address)
            await MainActor.run {
                balanceAmount = balance
            }
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
