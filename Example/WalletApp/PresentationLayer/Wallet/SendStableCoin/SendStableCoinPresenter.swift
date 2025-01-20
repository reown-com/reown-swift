import Foundation
import Combine
@preconcurrency import ReownWalletKit

enum L2: String {
    case Arbitrium
    case Optimism
    case Base
    case Sepolia

    var chainId: Blockchain {
        switch self {
        case .Arbitrium:
            return Blockchain("eip155:42161")!
        case .Optimism:
            return Blockchain("eip155:10")!
        case .Base:
            return Blockchain("eip155:8453")!
        case .Sepolia:
            return Blockchain("eip155:11155111")!
        }
    }
}

/// Your Presenter for handling logic: building calls, checking deployment, and routing
final class SendStableCoinPresenter: ObservableObject, SceneViewModel {
    @Published var selectedNetwork: L2 = .Sepolia
    @Published var recipient: String = ""
    @Published var amount: String = ""

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

    /// Reusable method that checks if wallet deployment is required
    func checkDeploymentRequired(for calls: [Call]) async throws -> PreparedGasAbstraction {
        do {
            let eoa = try Account(
                blockchain: selectedNetwork.chainId,
                accountAddress: importAccount.account.address
            )
            let x =  try await WalletKit.instance.prepare7702(EOA: eoa, calls: calls)
            return x

        } catch {
            print(error)
        }
        fatalError()
    }

    /// Called when user taps "Upgrade to Smart Account"
    /// In this example, it uses the same calls as typed in the text fields.
    func upgradeToSmartAccount() {
        Task {
            do {
                let calls = try getCalls()
                let preparedGasAbstraction = try await checkDeploymentRequired(for: calls)

                switch preparedGasAbstraction {
                case .deploymentRequired(auth: let auth, prepareDeployParams: let params):
                    // If deployment is required, present the upgrade flow
                    router.presentUpgradeToSmartAccount(
                        importAccount: importAccount,
                        network: selectedNetwork,
                        prepareDeployParams: params,
                        auth: auth,
                        chainId: selectedNetwork.chainId
                    )
                case .deploymentNotRequired:
                    // If not required, hide the button & show alert
                    AlertPresenter.present(
                        message: "deployment not required",
                        type: .error
                    )
                }
            } catch {
                // If something goes wrong with checkDeploymentRequired
                AlertPresenter.present(
                    message: error.localizedDescription,
                    type: .error
                )
            }
        }
    }

    /// Called when user taps "Send"
    /// Uses the presenter's `recipient` and `amount` directly
    func send() async  {
        do {

            // Build calls from the presenter's fields
            let calls = try getCalls()

            // Check if wallet deployment is required
            let preparedGasAbstraction = try await checkDeploymentRequired(for: calls)
            let eoa = try Account(
                blockchain: selectedNetwork.chainId,
                accountAddress: importAccount.account.address
            )
            let signer = ETHSigner(importAccount: importAccount)

            switch preparedGasAbstraction {
            case .deploymentRequired(auth: let auth, prepareDeployParams: let deployParams):
                print("Deployment is required -> Show 'upgrade to smart account' screen")
                DispatchQueue.main.async { [unowned self] in
                    router.presentUpgradeToSmartAccount(
                        importAccount: importAccount,
                        network: selectedNetwork,
                        prepareDeployParams: deployParams,
                        auth: auth,
                        chainId: selectedNetwork.chainId
                    )
                }

            case .deploymentNotRequired(preparedSend: let preparedSend):
                print("Deployment not required -> sign & send userOp")

                let signature = try signer.signHash(preparedSend.hash)
                let userOpReceipt = try await WalletKit.instance.send(
                    EOA: eoa,
                    signature: signature,
                    params: preparedSend.sendParams
                )
                print("[GasAbstractionSigner] userOpReceipt: \(userOpReceipt)")
            }
        } catch {
            AlertPresenter.present(message: error.localizedDescription, type: .error)
        }
    }

    /// Build the [Call] array from the presenter's current `recipient` and `amount`
    private func getCalls() throws -> [Call] {
//        let eoa = try Account(
//            blockchain: selectedNetwork.chainId,
//            accountAddress: importAccount.account.address
//        )
//
//        let toAccount = try Account(
//            blockchain: selectedNetwork.chainId,
//            accountAddress: recipient
//        )
//
//        let call = WalletKit.instance.prepareUSDCTransferCall(
//            EOA: eoa,
//            to: toAccount,
//            amount: amount
//        )

        let call = Call(
            to: "0x23d8eE973EDec76ae91669706a587b9A4aE1361A",
            value: "0",
            input: ""
        )

        return [call]
    }
}
