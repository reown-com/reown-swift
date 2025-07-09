import Foundation
import Commons
import WalletConnectSign
import ReownWalletKit
import Web3

// MARK: - SendCallsResult Structure
private struct SendCallsResult: Codable {
    let id: String
    let capabilities: [String: AnyCodable]?
}

private struct CAIP345Capability: Codable {
    let caip2: String
    let transactionHashes: [String]
}

final class EOASigner {
    func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        let signer = ETHSigner(importAccount: importAccount)

        switch request.method {
        case "personal_sign":
            return signer.personalSign(request.params)

        case "eth_signTypedData":
            return signer.signTypedData(request.params)

        case "eth_sendTransaction":
            return try signer.sendTransaction(request.params)

        case "wallet_sendCalls":
            return try createSendCallsResponse(request: request)

        case "solana_signTransaction":
            return SOLSigner.signTransaction(request.params)

        default:
            // If something is not supported, throw an error or handle it
            throw Signer.Errors.notImplemented
        }
    }
    
    private func createSendCallsResponse(request: Request) throws -> AnyCodable {
        // Generate a unique ID for this batch of calls
        let batchId = UUID().uuidString
        
        // Create the CAIP-345 capability with the mocked transaction hash
        let caip345 = CAIP345Capability(
            caip2: "eip155:1",
            transactionHashes: ["0x4aa6c3e9f46fe6456e49570b173b5cc58a0b35837566c130c32f43dc0f8ffda6"]
        )
        
        // Create the response
        let result = SendCallsResult(
            id: batchId,
            capabilities: [
                "caip345": AnyCodable(caip345)
            ]
        )
        
        return AnyCodable(result)
    }
}
