import UIKit
import Combine
import Web3
import ReownWalletKit

final class CATransactionPresenter: ObservableObject {
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
                try await chainAbstractionService.broadcastTransactions(transactions: signedTransactions)
                let orchestrationId = routeResponseAvailable.orchestrationId
//                let statusResponseCompleted = try await WalletKit.instance.waitForSuccess(orchestrationId: orchestrationId, checkIn: routeResponseAvailable.metadata.checkIn)




                var status: StatusResponse = try await WalletKit.instance.status(orchestrationId: orchestrationId)
                while true {
                    switch status {
                    case .pending(let pending):
                        let delay = try UInt64(pending.checkIn) * 1_000_000
                        try await Task.sleep(nanoseconds: delay)
                        // Fetch the status again after the delay
                        status = try await WalletKit.instance.status(orchestrationId: orchestrationId)
                    case .completed(let completed):
                        // Handle the completed status
                        print("Transaction completed: \(completed)")
                        ActivityIndicatorManager.shared.stop()
                        return
                    case .error(let error):
                        // Handle the error
                        print("Transaction failed: \(error)")
                        ActivityIndicatorManager.shared.stop()
                        return
                    }
                }

                // wait routing is completed
                // broadcast initial transaction
            } catch {
                AlertPresenter.present(message: error.localizedDescription, type: .error)
            }
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
