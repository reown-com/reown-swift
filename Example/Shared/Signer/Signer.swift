import Foundation
import Commons
import WalletConnectSign
import ReownWalletKit

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
    enum Errors: Error {
        case notImplemented
        case accountForRequestNotFound
    }

    private init() {}

    static func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        let requestedAddress = try await getRequestedAddress(request)
        if requestedAddress == importAccount.account.address {
            return try signWithEOA(request: request, importAccount: importAccount)
        }
        let smartAccount = try await WalletKit.instance.getSmartAccount(ownerAccount: importAccount.account)
        if smartAccount.address == requestedAddress {
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

        throw cantGetRequestedAddress
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
            let params = try request.params.get([String].self)
            let message = params[0]
            let signedMessage = try WalletKit.instance.signMessage(message)
            return AnyCodable(signedMessage)

        case "eth_signTypedData":
            let params = try request.params.get([String].self)
            let message = params[0]
            let signedMessage = try WalletKit.instance.signMessage(message)
            return AnyCodable(signedMessage)

        case "eth_sendTransaction":
            let params = try request.params.get([YttriumWrapper.Transaction].self)
            let prepareSendTransactions = try await WalletKit.instance.prepareSendTransactions(params, ownerAccount: ownerAccount)

            let signer = ETHSigner(importAccount: importAccount)

            let signature = try signer.signHash(prepareSendTransactions.hash)

            let ownerSignature = OwnerSignature(owner: ownerAccount.address, signature: signature)

            let userOpHash = try await WalletKit.instance.doSendTransaction(signatures: [ownerSignature], params: prepareSendTransactions.doSendTransactionParams, ownerAccount: ownerAccount)
            return AnyCodable(userOpHash)

        case "wallet_sendCalls":
            let params = try request.params.get([SendCallsParams].self)
            guard let calls = params.first?.calls else {
                fatalError()
            }

            let transactions = calls.map {
                YttriumWrapper.Transaction(
                    to: $0.to!,
                    value: $0.value!,
                    data: $0.data!
                )
            }

            let prepareSendTransactions = try await accountClient.prepareSendTransactions(transactions)

            let signer = ETHSigner(importAccount: importAccount)

            let signature = try signer.signHash(prepareSendTransactions.hash)

            let ownerSignature = OwnerSignature(owner: ownerAccount.address, signature: signature)

            let userOpHash = try await accountClient.doSendTransaction(signatures: [ownerSignature], params: prepareSendTransactions.doSendTransactionParams)

            return AnyCodable(userOpHash)

        default:
            throw Errors.notImplemented
        }
    }
}

extension Signer.Errors: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notImplemented:   return "Requested method is not implemented"
        case .accountForRequestNotFound: return "Account for request not found"
        }
    }
}
