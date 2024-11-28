import Foundation
import Commons
import WalletConnectSign
import ReownWalletKit
import Web3

struct SendCallsParams: Codable {
    let version: String
    let from: String
    let calls: [Call]

    struct Call: Codable {
        let to: String?
        let value: String?
        let data: String?
        let chainId: String?
    }
}


final class Signer {
    enum Errors: LocalizedError {
        case notImplemented
        case accountForRequestNotFound
        case cantFindRequestedAddress
    }

    private init() {}

    static func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        let requestedAddress = try await getRequestedAddress(request)
        if requestedAddress == importAccount.account.address {
            return try signWithEOA(request: request, importAccount: importAccount)
        }
        let smartAccount = try await WalletKit.instance.getSmartAccount(ownerAccount: importAccount.account)
        if smartAccount.address.lowercased() == requestedAddress.lowercased() {
            return try await signWithSmartAccount(request: request, importAccount: importAccount)
        }
        throw Errors.accountForRequestNotFound
    }

    private static func getRequestedAddress(_ request: Request) async throws -> String {
        // Attempt to decode params for transaction requests encapsulated in an array of dictionaries
        if let paramsArray = try? request.params.get([AnyCodable].self),
           let firstParam = paramsArray.first?.value as? [String: Any],
           let account = firstParam["from"] as? String {
            return account
        }

        // Attempt to decode params for signing message requests
        if let paramsArray = try? request.params.get([AnyCodable].self) {
            if request.method == "personal_sign" || request.method == "eth_signTypedData" {
                // Typically, the account address is the second parameter for personal_sign and eth_signTypedData
                if paramsArray.count > 1,
                   let account = paramsArray[1].value as? String {
                    return account
                }
            }
            // Handle the `wallet_sendCalls` method
            if request.method == "wallet_sendCalls" {
                if let sendCallsParams = paramsArray.first?.value as? [String: Any],
                   let account = sendCallsParams["from"] as? String {
                    return account
                }
            }
        }

        throw Errors.cantFindRequestedAddress
    }

    private static func signWithEOA(request: Request, importAccount: ImportAccount) throws -> AnyCodable {
        let signer = ETHSigner(importAccount: importAccount)

        switch request.method {
        case "personal_sign":
            return signer.personalSign(request.params)

        case "eth_signTypedData":
            return signer.signTypedData(request.params)

        case "eth_sendTransaction":
            return try signer.sendTransaction(request.params)

        case "solana_signTransaction":
            return SOLSigner.signTransaction(request.params)

        default:
            throw Errors.notImplemented
        }
    }

    private static func signWithSmartAccount(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {

        let ownerAccount = Account(blockchain: request.chainId, address: importAccount.account.address)!

        switch request.method {
        case "personal_sign":
            fatalError("3 step signing not yet implemented in uniffi")
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
            let params = try request.params.get([String].self)
            let message = params[0]
            fatalError("not implemented")
//            let signedMessage = try WalletKit.instance.signMessage(message)
//            return AnyCodable(signedMessage)

        case "eth_sendTransaction":
            struct Tx: Codable {
                var to: String
                var value: String
                var data: String
            }
            let params = try request.params.get([Tx].self).map { FfiTransaction(to: $0.to, value: $0.value, data: $0.data)}
            let prepareSendTransactions = try await WalletKit.instance.prepareSendTransactions(params, ownerAccount: ownerAccount)

            let signer = ETHSigner(importAccount: importAccount)

            let signature = try signer.signHash(prepareSendTransactions.hash)

            let ownerSignature = OwnerSignature(owner: ownerAccount.address, signature: signature)

            let userOpHash = try await WalletKit.instance.doSendTransaction(signatures: [ownerSignature], doSendTransactionParams: prepareSendTransactions.doSendTransactionParams, ownerAccount: ownerAccount)
            return AnyCodable(userOpHash)

        case "wallet_sendCalls":
            let params = try request.params.get([SendCallsParams].self)
            guard let calls = params.first?.calls else {
                fatalError()
            }

            let transactions = calls.map {
                FfiTransaction(
                    to: $0.to!,
                    value: $0.value ?? "0",
                    data: $0.data ?? ""
                )
            }

            let prepareSendTransactions = try await WalletKit.instance.prepareSendTransactions(transactions, ownerAccount: ownerAccount)

            let signer = ETHSigner(importAccount: importAccount)

            let signature = try signer.signHash(prepareSendTransactions.hash)

            let ownerSignature = OwnerSignature(owner: ownerAccount.address, signature: signature)

            let userOpHash = try await WalletKit.instance.doSendTransaction(signatures: [ownerSignature], doSendTransactionParams: prepareSendTransactions.doSendTransactionParams, ownerAccount: ownerAccount)

            Task {
                do {
                    let receipt = try await WalletKit.instance.waitForUserOperationReceipt(userOperationHash: userOpHash, ownerAccount: ownerAccount)
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

    private static func prepareMessageToSign(_ messageToSign: String) -> [Byte] {
        let dataToSign: [Byte]
        if messageToSign.hasPrefix("0x") {
            // Remove "0x" prefix and create hex data
            let hexString = String(messageToSign.dropFirst(2))
            let messageData = Data(hex: hexString)
            dataToSign = dataToHash(messageData)
        } else {
            // Plain text message, convert directly to data
            let messageData = Data(messageToSign.utf8)
            dataToSign = dataToHash(messageData)
        }

        return dataToSign
    }

    private static func dataToHash(_ data: Data) -> [Byte] {
        let prefix = "\u{19}Ethereum Signed Message:\n"
        let prefixData = (prefix + String(data.count)).data(using: .utf8)!
        let prefixedMessageData = prefixData + data
        return .init(hex: prefixedMessageData.toHexString())
    }

}

extension Signer.Errors {
    var errorDescription: String? {
        switch self {
        case .notImplemented:   return "Requested method is not implemented"
        case .accountForRequestNotFound: return "Account for request not found"
        case .cantFindRequestedAddress: return "Can't find requested address"
        }
    }
}


