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
    static func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        // Handle TON methods
        if request.method.starts(with: "ton_") {
            let requestedAddress = try await getRequestedAddress(request)
            let tonAccountStorage = TonAccountStorage()

            if let tonAddress = tonAccountStorage.getAddress(for: request.chainId),
               requestedAddress.lowercased() == tonAddress.lowercased() {
                let tonSigner = TonSigner()
                return try await tonSigner.sign(request: request)
            }
            throw Errors.accountForRequestNotFound
        }
        // Handle Tron methods
        if request.method.starts(with: "tron_") {
            let requestedAddress = try await getRequestedAddress(request)
            let tronAccountStorage = TronAccountStorage()

            if let tronAddress = tronAccountStorage.getAddress(for: request.chainId),
               requestedAddress.lowercased() == tronAddress.lowercased() {
                let tronSigner = TronSigner()
                return try await tronSigner.sign(request: request)
            }
            throw Errors.accountForRequestNotFound
        }
        // Handle Sui methods
        if request.method.starts(with: "sui_") {
            let requestedAddress = try await getRequestedAddress(request)
            let suiAccountStorage = SuiAccountStorage()

            if let suiAddress = suiAccountStorage.getAddress(),
               requestedAddress.lowercased() == suiAddress.lowercased() {
                let suiSigner = SuiSigner()
                return try await suiSigner.sign(request: request)
            }
            throw Errors.accountForRequestNotFound
        }

        // Handle Stacks methods
        if request.method.starts(with: "stx_") {
            let requestedAddress = try await getRequestedAddress(request)
            let stacksAccountStorage = StacksAccountStorage()

            if let stacksAddress = try stacksAccountStorage.getAddress(for: request.chainId),
               requestedAddress.lowercased() == stacksAddress.lowercased() {
                let stacksSigner = StacksSigner()
                return try await stacksSigner.sign(request: request)
            }
            throw Errors.accountForRequestNotFound
        }

        // Default EOA route
        let requestedAddress = try await getRequestedAddress(request)

        if requestedAddress.lowercased() == importAccount.account.address.lowercased() {
            let eoaSigner = EOASigner()
            return try await eoaSigner.sign(request: request, importAccount: importAccount)
        }

        throw Errors.accountForRequestNotFound
    }

    // Determine requested address for different method families
    private static func getRequestedAddress(_ request: Request) async throws -> String {
        // TON methods: read from TonAccountStorage for specific chain
        if request.method.starts(with: "ton_") {
            let tonAccountStorage = TonAccountStorage()
            if let tonAddress = tonAccountStorage.getAddress(for: request.chainId) {
                return tonAddress
            }
            throw Errors.cantFindRequestedAddress
        }
        // Tron methods: read from TronAccountStorage for specific chain
        if request.method.starts(with: "tron_") {
            let tronAccountStorage = TronAccountStorage()
            if let tronAddress = tronAccountStorage.getAddress(for: request.chainId) {
                return tronAddress
            }
            throw Errors.cantFindRequestedAddress
        }
        // Sui methods: read from SuiAccountStorage
        if request.method.starts(with: "sui_") {
            let suiAccountStorage = SuiAccountStorage()
            if let suiAddress = suiAccountStorage.getAddress() {
                return suiAddress
            }
            throw Errors.cantFindRequestedAddress
        }

        // Stacks methods: read from StacksAccountStorage for specific chain
        if request.method.starts(with: "stx_") {
            let stacksAccountStorage = StacksAccountStorage()
            if let stacksAddress = try stacksAccountStorage.getAddress(for: request.chainId) {
                return stacksAddress
            }
            throw Errors.cantFindRequestedAddress
        }

        // EIP-155 methods
        print("[Signer] getRequestedAddress for method: \(request.method)")

        if let paramsArray = try? request.params.get([AnyCodable].self) {
            print("[Signer] params array count: \(paramsArray.count)")

            // eth_sendTransaction, eth_call - address in "from" field of first param object
            if let firstParam = paramsArray.first?.value as? [String: Any],
               let account = firstParam["from"] as? String {
                print("[Signer] Found address in 'from' field: \(account)")
                return account
            }

            // personal_sign: params are [message, address]
            if request.method == "personal_sign" {
                if paramsArray.count > 1,
                   let account = paramsArray[1].value as? String {
                    print("[Signer] personal_sign address at index 1: \(account)")
                    return account
                }
            }

            // eth_signTypedData, eth_signTypedData_v4: params are [address, typedData]
            if request.method == "eth_signTypedData" || request.method == "eth_signTypedData_v4" {
                if let account = paramsArray.first?.value as? String {
                    print("[Signer] \(request.method) address at index 0: \(account)")
                    return account
                }
                print("[Signer] \(request.method) could not extract address from first param")
            }

            // wallet_sendCalls: address in "from" field
            if request.method == "wallet_sendCalls" {
                if let sendCallsParams = paramsArray.first?.value as? [String: Any],
                   let account = sendCallsParams["from"] as? String {
                    print("[Signer] wallet_sendCalls address: \(account)")
                    return account
                }
            }
        } else {
            print("[Signer] Could not parse params as array")
        }

        print("[Signer] Could not find requested address for method: \(request.method)")
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
