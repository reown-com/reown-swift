import Foundation
import Commons
import WalletConnectSign
import ReownWalletKit
import Web3

final class GasAbstractionSigner {
    func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        switch request.method {
        case "personal_sign":
            // If you have a personal_sign route:
            throw Signer.Errors.notImplemented

        case "eth_sendTransaction":
            let calls = try request.params.get([Tx].self)
                .map { Call(to: $0.to, value: $0.value, input: $0.data) }
            let preparedGasAbstraction = try await WalletKit.instance
                .prepare7702(EOA: importAccount.account, calls: calls)
            let signer = ETHSigner(importAccount: importAccount)

            switch preparedGasAbstraction {
            case .deploymentRequired(auth: let auth, prepareDeployParams: let prepareDeployParams):
                let signature = try signer.signHash(auth.hash)
                let authSig = SignedAuthorization(auth: auth.auth, signature: signature)

                let _ = try await WalletKit.instance
                    .prepareDeploy(EOA: importAccount.account, authSig: authSig, params: prepareDeployParams)


                fatalError()
                // sign

//                let userOpReceipt = try await WalletKit.instance
//                    .send(EOA: importAccount.account, signature: signature, params: preparedSend.sendParams)
//
//                return AnyCodable(userOpReceipt)

            case .deploymentNotRequired(preparedSend: let preparedSend):
                let signature = try signer.signHash(preparedSend.hash)

                let userOpReceipt = try await WalletKit.instance
                    .send(EOA: importAccount.account, signature: signature, params: preparedSend.sendParams)

                return AnyCodable(userOpReceipt)
            }

        case "wallet_sendCalls":
            // If gas-abstraction also supports multiple calls:
            throw Signer.Errors.notImplemented

        default:
            throw Signer.Errors.notImplemented
        }
    }
}
