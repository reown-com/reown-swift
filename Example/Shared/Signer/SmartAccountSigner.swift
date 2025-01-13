import Foundation
import Commons
import WalletConnectSign
import ReownWalletKit
import Web3

final class SmartAccountSigner {
    enum Errors: LocalizedError {
        case notImplemented
    }

    func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        let requestedChainId = request.chainId

        // Set up an ownerAccount from chainId and importAccount address
        let ownerAccount = Account(blockchain: requestedChainId, address: importAccount.account.address)!

        switch request.method {
        case "personal_sign":
            fatalError("implement 3 step signing")
//            let params = try request.params.get([String].self)
//            let requestedMessage = params[0]
//
//            let messageToSign = Self.prepareMessageToSign(requestedMessage)
//
//            let messageHash = messageToSign.sha3(.keccak256).toHexString()
//
//            // Step 1
//            let prepareSignMessage: PreparedSignMessage
//            do {
//                prepareSignMessage = try await WalletKit.instance.prepareSignMessage(messageHash, ownerAccount: ownerAccount)
//            } catch {
//                print(error)
//                throw error
//            }
//
//            // Sign prepared message
//            let dataToSign = prepareSignMessage.hash.data(using: .utf8)!
//            let privateKey = try! EthereumPrivateKey(hexPrivateKey: importAccount.privateKey)
//            let (v, r, s) = try! privateKey.sign(message: .init(Data(dataToSign)))
//            let result: String = "0x" + r.toHexString() + s.toHexString() + String(v + 27, radix: 16)
//
//            // Step 2
//            let prepareSign: PreparedSign
//            do {
//                prepareSign = try await WalletKit.instance.doSignMessage([result], ownerAccount: ownerAccount)
//            } catch {
//                print(error)
//                throw error
//            }
//
//            switch prepareSign {
//            case .signature(let signature):
//                return AnyCodable(signature)
//            case .signStep3(let preparedSignStep3):
//                // Step 3
//                let dataToSign = preparedSignStep3.hash.data(using: .utf8)!
//                let privateKey = try! EthereumPrivateKey(hexPrivateKey: importAccount.privateKey)
//                let (v, r, s) = try! privateKey.sign(message: .init(Data(dataToSign)))
//                let result: String = "0x" + r.toHexString() + s.toHexString() + String(v + 27, radix: 16)
//
//                let signature: String
//                do {
//                    signature = try await WalletKit.instance.finalizeSignMessage([result], signStep3Params: preparedSignStep3.signStep3Params, ownerAccount: ownerAccount)
//                } catch {
//                    print(error)
//                    throw error
//                }
//                return AnyCodable(signature)
//            }

        case "eth_signTypedData":
            fatalError("not implemented")


        case "eth_sendTransaction":
            let params = try request.params.get([Tx].self)
                .map { Call(to: $0.to, value: $0.value, input: $0.data) }

            let prepareSendTransactions = try await WalletKit.instance
                .prepareSendTransactions(params, ownerAccount: ownerAccount)

            let signer = ETHSigner(importAccount: importAccount)
            let signature = try signer.signHash(prepareSendTransactions.hash)
            let ownerSignature = OwnerSignature(owner: ownerAccount.address, signature: signature)

            let userOpHash = try await WalletKit.instance.doSendTransaction(
                signatures: [ownerSignature],
                doSendTransactionParams: prepareSendTransactions.doSendTransactionParams,
                ownerAccount: ownerAccount
            )
            return AnyCodable(userOpHash)

        case "wallet_sendCalls":
            let params = try request.params.get([SendCallsParams].self)
            guard let calls = params.first?.calls else {
                fatalError("No calls found")
            }

            let transactions = calls.map {
                Call(
                    to: $0.to ?? "",
                    value: $0.value ?? "0",
                    input: $0.data ?? ""
                )
            }

            let prepareSendTransactions = try await WalletKit.instance
                .prepareSendTransactions(transactions, ownerAccount: ownerAccount)

            let signer = ETHSigner(importAccount: importAccount)
            let signature = try signer.signHash(prepareSendTransactions.hash)
            let ownerSignature = OwnerSignature(owner: ownerAccount.address, signature: signature)

            let userOpHash = try await WalletKit.instance.doSendTransaction(
                signatures: [ownerSignature],
                doSendTransactionParams: prepareSendTransactions.doSendTransactionParams,
                ownerAccount: ownerAccount
            )

            // Optionally handle receipt
            Task {
                do {
                    let receipt = try await WalletKit.instance.waitForUserOperationReceipt(
                        userOperationHash: userOpHash,
                        ownerAccount: ownerAccount
                    )
                    let message = "User Op receipt received"
                    AlertPresenter.present(message: message, type: .success)
                } catch {
                    AlertPresenter.present(message: error.localizedDescription, type: .error)
                }
            }

            return AnyCodable(userOpHash)

        default:
            throw Errors.notImplemented
        }
    }
}
