
import Foundation
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

    /// Main entry point that decides which signer to call.
    static func sign(request: Request, importAccount: ImportAccount, gasAbstracted: Bool) async throws -> AnyCodable {
        let requestedAddress = try await getRequestedAddress(request)

        // If EOA address is requested
        if requestedAddress.lowercased() == importAccount.account.address.lowercased()
            && !gasAbstracted {
            // EOA route
            let eoaSigner = EOASigner()
            return try await eoaSigner.sign(request: request, importAccount: importAccount)
        }

        // If it's a smart account
        let smartAccount = try await WalletKit.instance.getSmartAccount(ownerAccount: importAccount.account)
        if smartAccount.address.lowercased() == requestedAddress.lowercased() {
            // Smart account route
            let smartAccountSigner = SmartAccountSigner()
            return try await smartAccountSigner.sign(request: request, importAccount: importAccount)
        }
        // If gas abstracted
        if gasAbstracted {
            let gasAbstractionSigner = GasAbstractionSigner()
            return try await gasAbstractionSigner.sign(request: request, importAccount: importAccount, chainId: request.chainId)
        }

        // If none of the above matched, throw an error
        throw Errors.accountForRequestNotFound
    }

    // The logic for finding a requested address stays the same
    private static func getRequestedAddress(_ request: Request) async throws -> String {
        if let paramsArray = try? request.params.get([AnyCodable].self),
           let firstParam = paramsArray.first?.value as? [String: Any],
           let account = firstParam["from"] as? String {
            return account
        }

        if let paramsArray = try? request.params.get([AnyCodable].self) {
            if request.method == "personal_sign" || request.method == "eth_signTypedData" {
                // Typically 2nd param for those
                if paramsArray.count > 1,
                   let account = paramsArray[1].value as? String {
                    return account
                }
            }
            if request.method == "wallet_sendCalls" {
                if let sendCallsParams = paramsArray.first?.value as? [String: Any],
                   let account = sendCallsParams["from"] as? String {
                    return account
                }
            }
        }

        throw Errors.cantFindRequestedAddress
    }
}

extension Signer.Errors {
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Requested method is not implemented"
        case .accountForRequestNotFound:
            return "Account for request not found"
        case .cantFindRequestedAddress:
            return "Can't find requested address"
        }
    }
}
