import Foundation
import Commons
import WalletConnectSign
import ReownWalletKit
import Web3

final class GasAbstractionSigner {
    func sign(request: Request, importAccount: ImportAccount, chainId: Blockchain) async throws -> AnyCodable {
        print("[GasAbstractionSigner] sign() called with request method: \(request.method)")

        switch request.method {
        case "personal_sign":
            print("[GasAbstractionSigner] personal_sign route called — not implemented yet")
            throw Signer.Errors.notImplemented

        case "eth_sendTransaction":
            print("[GasAbstractionSigner] eth_sendTransaction route called")

            let calls = try request.params.get([Tx].self)
                .map {
                    print("[GasAbstractionSigner] Tx: \($0)")
                    return Call(to: $0.to, value: $0.value, input: $0.data)
                }
            print("[GasAbstractionSigner] Prepared \(calls.count) calls")

            let eoa = try! Account(blockchain: chainId, accountAddress: importAccount.account.address)
            let preparedGasAbstraction = try await WalletKit.instance.prepare7702(
                EOA: eoa,
                calls: calls
            )
            print("[GasAbstractionSigner] preparedGasAbstraction: \(preparedGasAbstraction)")

            let signer = ETHSigner(importAccount: importAccount)

            switch preparedGasAbstraction {
            case .deploymentRequired(auth: let auth, prepareDeployParams: let prepareDeployParams):
                print("[GasAbstractionSigner] Deployment is required")
                print("[GasAbstractionSigner] auth hash: \(auth.hash)")

                let signature = try signer.signHash(auth.hash)
                print("[GasAbstractionSigner] signature: \(signature)")

                let authSig = SignedAuthorization(auth: auth.auth, signature: signature)
                print("[GasAbstractionSigner] authSig: \(authSig)")

                let preparedSend = try await WalletKit.instance.prepareDeploy(
                    EOA: eoa,
                    authSig: authSig,
                    params: prepareDeployParams
                )
                print("[GasAbstractionSigner] preparedSend: \(preparedSend)")

                let userOpReceipt = try await WalletKit.instance.send(
                    EOA: eoa,
                    signature: signature,
                    params: preparedSend.sendParams
                )
                print("[GasAbstractionSigner] userOpReceipt: \(userOpReceipt)")

                return AnyCodable(userOpReceipt)

            case .deploymentNotRequired(preparedSend: let preparedSend):
                print("[GasAbstractionSigner] Deployment not required")
                print("[GasAbstractionSigner] preparedSend hash: \(preparedSend.hash)")

                let signature = try signer.signHash(preparedSend.hash)
                print("[GasAbstractionSigner] signature: \(signature)")

                let userOpReceipt = try await WalletKit.instance.send(
                    EOA: eoa,
                    signature: signature,
                    params: preparedSend.sendParams
                )
                print("[GasAbstractionSigner] userOpReceipt: \(userOpReceipt)")

                return AnyCodable(userOpReceipt)
            }

        case "wallet_sendCalls":
            print("[GasAbstractionSigner] wallet_sendCalls route called — not implemented yet")
            throw Signer.Errors.notImplemented

        default:
            print("[GasAbstractionSigner] Unsupported method: \(request.method)")
            throw Signer.Errors.notImplemented
        }
    }
}
