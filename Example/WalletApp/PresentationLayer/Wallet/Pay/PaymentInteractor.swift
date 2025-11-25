import Foundation
import Combine
import ReownWalletKit
import Commons
import YttriumUtilsWrapper

final class PaymentInteractor {
    private let paymentService: PaymentService
    private let account: ImportAccount
    
    private static let evmSigningClient: EvmSigningClient = {
        let metadata = PulseMetadata(
            url: nil,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            sdkVersion: "reown-swift-mobile-1.0",
            sdkPlatform: "mobile"
        )
        return EvmSigningClient(projectId: InputConfig.projectId, pulseMetadata: metadata)
    }()

    init(paymentService: PaymentService, account: ImportAccount) {
        self.paymentService = paymentService
        self.account = account
    }

    func getPaymentInfo(paymentId: String) async throws -> PaymentInfo {
        return try await paymentService.getPaymentInfo(paymentId: paymentId)
    }

    func buildPayment(paymentId: String) async throws -> PaymentRPC {
        return try await paymentService.buildPayment(paymentId: paymentId, address: account.account.address)
    }

    func submit(paymentId: String, signature: String) async throws {
        try await paymentService.submit(paymentId: paymentId, signature: signature)
    }
    
    func sign(rpc: PaymentRPC) async throws -> String {
        if rpc.rpc.method == "eth_signTypedData_v4" {
            // Currently using ETHSigner (which might have mock implementation).
            let signer = ETHSigner(importAccount: account)
            if rpc.rpc.params.count > 1 {
                let result = signer.signTypedData(rpc.rpc.params[1])
                if let signature = result.value as? String {
                    return signature
                }
            }
            throw Errors.signingFailed
        } else if rpc.rpc.method == "eth_sendTransaction" {
            // Use EvmSigningClient for transactions as requested
            // rpc.rpc.params is [AnyCodable].
            // AnyCodable wraps the array of parameters if it was decoded as such, 
            // but here rpc.rpc.params IS the array.
            
             guard let firstParam = rpc.rpc.params.first,
                   let txParams = try? firstParam.get(EthSendTransactionParams.self) else {
                 throw Errors.invalidTransactionParams
             }
            
            let transactionParams = SignAndSendParams(
                chainId: "8453", // Base Chain ID
                from: txParams.from ?? account.account.address,
                to: txParams.to,
                value: txParams.value ?? "0x0",
                data: txParams.data,
                gasLimit: txParams.gas ?? "0x0",
                maxFeePerGas: txParams.maxFeePerGas,
                maxPriorityFeePerGas: txParams.maxPriorityFeePerGas,
                nonce: txParams.nonce
            )
            
            let result = try await Self.evmSigningClient.signAndSend(
                params: transactionParams,
                signer: account.privateKey
            )
            return result.transactionHash
        }
        
        throw Errors.unsupportedMethod
    }
    
    enum Errors: Error {
        case unsupportedMethod
        case signingFailed
        case invalidTransactionParams
    }
}

struct EthSendTransactionParams: Codable {
    let from: String?
    let to: String?
    let value: String?
    let data: String?
    let gas: String?
    let maxFeePerGas: String?
    let maxPriorityFeePerGas: String?
    let nonce: String?
}
