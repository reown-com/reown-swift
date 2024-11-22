import UIKit
import Combine
import Web3
import ReownWalletKit

final class CATransactionPresenter: ObservableObject {
    // Published properties to be used in the view
    @Published var payingAmount: Double = 10.00
    @Published var balanceAmount: Double = 5.00
    @Published var bridgingAmount: Double = 5.00
    @Published var bridgingSource: String = "Optimism"
    @Published var appURL: String = "https://sampleapp.com"
    @Published var networkName: String = "Arbitrum"
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
                let signedTransactions = try await chainAbstractionService.signTransactions()
                try await chainAbstractionService.broadcastTransactions(transactions: signedTransactions)

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
}

// MARK: - Private functions
private extension CATransactionPresenter {
    func setupInitialState() {
        // Initialize state if necessary
    }
}

// MARK: - SceneViewModel
extension CATransactionPresenter: SceneViewModel {}
