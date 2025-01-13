import Foundation
import Commons
import WalletConnectSign
import ReownWalletKit
import Web3

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

        case "solana_signTransaction":
            return SOLSigner.signTransaction(request.params)

        default:
            // If something is not supported, throw an error or handle it
            throw Signer.Errors.notImplemented
        }
    }
}
