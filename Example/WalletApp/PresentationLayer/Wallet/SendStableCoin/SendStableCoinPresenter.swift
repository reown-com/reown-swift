import Foundation
import Combine
@preconcurrency import ReownWalletKit

enum L2: String {
    case Arbitrium
    case Optimism
    case Base

    var chainId: Blockchain {
        switch self {
        case .Arbitrium:
            return Blockchain("eip155:42161")!
        case .Optimism:
            return Blockchain("eip155:10")!
        case .Base:
            return Blockchain("eip155:8453")!
        }
    }
}

/// Your Presenter for handling logic: building calls, checking deployment, and routing
final class SendStableCoinPresenter: ObservableObject, SceneViewModel {
    @Published var selectedNetwork: L2 = .Base
    @Published var recipient: String = "0x2bb169662b61f3D8f8318F800F686389C8a72961"
    @Published var amount: String = "1"
    @Published var transactionCompleted: Bool = false
    @Published var transactionResult: String? = nil

    let router: SendStableCoinRouter
    let importAccount: ImportAccount

    init(router: SendStableCoinRouter,
         importAccount: ImportAccount) {
        self.router = router
        self.importAccount = importAccount
    }

    func set(network: L2) {
        selectedNetwork = network
    }


    func send() async throws  {
        do {

            let call = try getCall()



            ActivityIndicatorManager.shared.start()
            let routeResponseSuccess = try await WalletKit.instance.prepare(chainId: selectedNetwork.chainId.absoluteString, from: importAccount.account.address, call: call)
            await MainActor.run {
                switch routeResponseSuccess {
                case .success(let routeResponseSuccess):
                    switch routeResponseSuccess {
                    case .available(let routeResponseAvailable):
                        router.presentCATransaction(call: call, from: importAccount.account.address, chainId: selectedNetwork.chainId, importAccount: importAccount, routeResponseAvailable: routeResponseAvailable)
                    case .notRequired(let routeResponseNotRequired):
                        AlertPresenter.present(message: "Routing not required", type: .success)
                        // complete the transaction
                    }
                case .error(let routeResponseError):
                    AlertPresenter.present(message: "Route response error: \(routeResponseError)", type: .success)
                    }
                }
            ActivityIndicatorManager.shared.stop()
        } catch {
            await MainActor.run {
                ActivityIndicatorManager.shared.stop()
                AlertPresenter.present(message: "CA error: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func getCall() throws -> Call {
        let eoa = try Account(
            blockchain: selectedNetwork.chainId,
            accountAddress: importAccount.account.address
        )

        let toAccount = try Account(
            blockchain: selectedNetwork.chainId,
            accountAddress: recipient
        )

        // 1) Parse the user’s string (e.g. "1") into Decimal:
        guard let decimalAmount = Decimal(string: amount) else {
            // Handle parse failure
            throw NSError(domain: "SendStableCoinPresenter", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid numeric input: \(amount)"
            ])
        }

        // 2) Multiply by 10^6 because USDC uses 6 decimals:
        let baseUnitsDecimal = decimalAmount * Decimal(1_000_000)

        // 3) Convert back to String to pass into prepareUSDCTransferCall:
        let baseUnitsString = NSDecimalNumber(decimal: baseUnitsDecimal).stringValue

        // Now use `baseUnitsString` as the amount in base units:
        let call = WalletKit.instance.prepareUSDCTransferCall(
            EOA: eoa,
            to: toAccount,
            amount: baseUnitsString
        )

        return call
    }
}


