import Foundation
import ReownWalletKit

final class CantonSigner {
    enum Errors: LocalizedError {
        case unsupportedMethod(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedMethod(let method):
                return "Unsupported Canton method: \(method)"
            }
        }
    }

    func sign(request: Request) async throws -> AnyCodable {
        let networkId = request.chainId.absoluteString

        switch request.method {
        case "canton_listAccounts":
            return listAccounts(networkId: networkId)
        case "canton_getPrimaryAccount":
            return getPrimaryAccount(networkId: networkId)
        case "canton_getActiveNetwork":
            return getActiveNetwork(networkId: networkId)
        case "canton_status":
            return getStatus(networkId: networkId)
        case "canton_ledgerApi":
            return ledgerApi(request: request)
        case "canton_signMessage":
            return signMessage()
        case "canton_prepareSignExecute":
            return prepareSignExecute(request: request)
        default:
            throw Errors.unsupportedMethod(request.method)
        }
    }

    // MARK: - Mock Responses

    private func accountObject(networkId: String) -> [String: Any] {
        return [
            "primary": true,
            "partyId": CantonAccountStorage.partyId,
            "status": "allocated",
            "hint": "operator",
            "publicKey": CantonAccountStorage.publicKeyBase64,
            "namespace": CantonAccountStorage.cantonNamespace,
            "networkId": networkId,
            "signingProviderId": "participant",
            "disabled": false
        ]
    }

    private func listAccounts(networkId: String) -> AnyCodable {
        return AnyCodable(any: [accountObject(networkId: networkId)])
    }

    private func getPrimaryAccount(networkId: String) -> AnyCodable {
        return AnyCodable(any: accountObject(networkId: networkId))
    }

    private func getActiveNetwork(networkId: String) -> AnyCodable {
        return AnyCodable(any: [
            "networkId": networkId,
            "ledgerApi": "http://127.0.0.1:5003"
        ])
    }

    private func getStatus(networkId: String) -> AnyCodable {
        return AnyCodable(any: [
            "provider": [
                "id": "remote-da",
                "version": "3.4.0",
                "providerType": "remote"
            ],
            "connection": [
                "isConnected": true,
                "isNetworkConnected": true
            ],
            "network": [
                "networkId": networkId,
                "ledgerApi": "http://127.0.0.1:5003"
            ]
        ] as [String: Any])
    }

    private func ledgerApi(request: Request) -> AnyCodable {
        var resource = "/unknown"
        if let params = try? request.params.get([String: AnyCodable].self),
           let res = params["resource"]?.value as? String {
            resource = res
        }

        if resource == "/v2/version" {
            return AnyCodable(any: [
                "response": "{\"version\":\"3.4.0\",\"features\":{}}"
            ])
        } else {
            return AnyCodable(any: [
                "response": "{\"mock\":true,\"resource\":\"\(resource)\"}"
            ])
        }
    }

    private func signMessage() -> AnyCodable {
        return AnyCodable(any: [
            "signature": CantonAccountStorage.publicKeyBase64,
            "publicKey": CantonAccountStorage.publicKeyBase64
        ])
    }

    private func prepareSignExecute(request: Request) -> AnyCodable {
        var commandId = "mock-command-id-\(Int(Date().timeIntervalSince1970 * 1000))"
        if let params = try? request.params.get([String: AnyCodable].self),
           let id = params["commandId"]?.value as? String {
            commandId = id
        }

        return AnyCodable(any: [
            "status": "executed",
            "commandId": commandId,
            "payload": [
                "updateId": "mock-tx-update-id",
                "completionOffset": 42
            ] as [String: Any]
        ] as [String: Any])
    }
}
