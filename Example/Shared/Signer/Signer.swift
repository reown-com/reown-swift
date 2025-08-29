
import Foundation
import WalletConnectYttrium
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
    static func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        let requestedAddress = try await getRequestedAddress(request)

        // If EOA address is requested
        if requestedAddress.lowercased() == importAccount.account.address.lowercased() {
            // EOA route
            let eoaSigner = EOASigner()
            return try await eoaSigner.sign(request: request, importAccount: importAccount)
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
