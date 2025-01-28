import Foundation
import ReownWalletKit

final class UpgradeToSmartAccountPresenter: ObservableObject, SceneViewModel {
    @Published var selectedNetwork: L2
    @Published var doNotAskAgain = false

    let router: UpgradeToSmartAccountRouter
    let importAccount: ImportAccount
    let prepareDeployParams: PrepareDeployParams
    let auth: PreparedGasAbstractionAuthorization
    let chainId: Blockchain

    init(router: UpgradeToSmartAccountRouter,
         importAccount: ImportAccount,
         network: L2,
         prepareDeployParams: PrepareDeployParams,
         auth: PreparedGasAbstractionAuthorization,
         chainId: Blockchain) {
        self.router = router
        self.importAccount = importAccount
        self.selectedNetwork = network
        self.prepareDeployParams = prepareDeployParams
        self.auth = auth
        self.chainId = chainId
    }

    func signAndUpgrade() async throws {
        do {
            let signer = ETHSigner(importAccount: importAccount)

            let eoa = try! Account(blockchain: chainId, accountAddress: importAccount.account.address)

            let signature = try signer.signHash(auth.hash)

            let authSig = SignedAuthorization(auth: auth.auth, signature: signature)

            let preparedSend = try await WalletKit.instance.prepareDeploy(
                EOA: eoa,
                authSig: authSig,
                params: prepareDeployParams
            )

            let userOpSignature = try signer.signHash(preparedSend.hash)

            let userOpReceipt = try await WalletKit.instance.send(
                EOA: eoa,
                signature: userOpSignature,
                params: preparedSend.sendParams
            )
            ActivityIndicatorManager.shared.stop()
            AlertPresenter.present(message: "Succesfully upgraded EOA to smart account", type: .success)
            router.dismiss()
        } catch {
            AlertPresenter.present(message: error.localizedDescription, type: .error)
            print(error)
            ActivityIndicatorManager.shared.stop()
        }
    }

    func cancel() {
        router.dismiss()
    }
}
