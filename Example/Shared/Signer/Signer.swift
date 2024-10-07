import Foundation
import Commons
import WalletConnectSign
import YttriumWrapper

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

enum SmartAccountType {
    case simple
    case safe
}

final class Signer {
    enum Errors: Error {
        case notImplemented
        case unknownSmartAccountType
    }

    private init() {}

    static func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        if let accountType = try await getRequestedSmartAccountType(request) {
            return try await signWithSmartAccount(request: request, accountType: accountType)
        } else {
            return try signWithEOA(request: request, importAccount: importAccount)
        }
    }

    private static func getRequestedSmartAccountType(_ request: Request) async throws -> SmartAccountType? {
        let account = try await getRequestedAccount(request)
        if account == nil {
            return nil
        }

        let safeSmartAccountAddress = try await SmartAccountSafe.instance.getClient().getAddress()

        if account?.lowercased() == safeSmartAccountAddress.lowercased() {
            return .safe
        }

        return nil
    }

    private static func getRequestedAccount(_ request: Request) async throws -> String? {
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

        return nil
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

    private static func signWithSmartAccount(request: Request, accountType: SmartAccountType) async throws -> AnyCodable {
        let client: AccountClientProtocol
        switch accountType {
        case .safe:
            client = await SmartAccountSafe.instance.getClient()
        default:
            fatalError("Only safe is currently supported")
        }

        switch request.method {
        case "personal_sign":
            let params = try request.params.get([String].self)
            let message = params[0]
            let signedMessage = try client.signMessage(message)
            return AnyCodable(signedMessage)

        case "eth_signTypedData":
            let params = try request.params.get([String].self)
            let message = params[0]
            let signedMessage = try client.signMessage(message)
            return AnyCodable(signedMessage)

        case "eth_sendTransaction":
            let params = try request.params.get([YttriumWrapper.Transaction].self)
            let result = try await client.sendTransactions(params)
            return AnyCodable(result)

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

            let userOpHash = try await client.sendTransactions(transactions)

            Task {
                let userOpReceipt = try await SmartAccountSafe.instance.getClient().waitForUserOperationReceipt(userOperationHash: userOpHash)
                guard let userOpReceiptSting = userOpReceipt.jsonString else { return }
                AlertPresenter.present(message: userOpReceiptSting, type: .info)
            }

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
        case .unknownSmartAccountType: return "Unknown smart account type"
        }
    }
}
