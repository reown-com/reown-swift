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
            if rpc.rpc.params.count > 1 {
                let param = rpc.rpc.params[1]
                let jsonData = try JSONEncoder().encode(param)
                
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    // Use EvmSigningClient for typed data signing
                    // Returns the full ERC-3009 authorization JSON
                    let authorizationJson = try await Self.evmSigningClient.signTypedData(
                        jsonData: jsonString,
                        signer: account.privateKey
                    )
                    return authorizationJson
                }
            }
            throw Errors.signingFailed
        } else if rpc.rpc.method == "eth_sendTransaction" {
             guard let firstParam = rpc.rpc.params.first,
                   let txParams = try? firstParam.get(EthSendTransactionParams.self) else {
                 throw Errors.invalidTransactionParams
             }
            
            let transactionParams = SignAndSendParams(
                chainId: "8453", // Base Sepolia Chain ID
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
