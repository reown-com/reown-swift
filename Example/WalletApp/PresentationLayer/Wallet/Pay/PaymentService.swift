import Foundation
import HTTPClient
import Commons

struct PaymentInfo: Codable {
    let paymentId: String
    let amount: Int
    let referenceId: String
    let status: String
}

struct PaymentRPC: Codable {
    let rpc: RPCMethod
}

struct RPCMethod: Codable {
    let method: String
    let params: [AnyCodable]
}

struct EmptyResponse: Codable {}

final class PaymentService {
    private let httpClient: HTTPNetworkClient

    init() {
        self.httpClient = HTTPNetworkClient(host: "pay-mvp-core-worker.walletconnect-v1-bridge.workers.dev")
    }

    func getPaymentInfo(paymentId: String) async throws -> PaymentInfo {
        return try await httpClient.request(PaymentInfo.self, at: PaymentAPI.getPaymentInfo(paymentId: paymentId))
    }

    func buildPayment(paymentId: String, address: String) async throws -> PaymentRPC {
        return try await httpClient.request(PaymentRPC.self, at: PaymentAPI.buildPayment(paymentId: paymentId, address: address))
    }

    func submit(paymentId: String, signature: String) async throws {
        _ = try await httpClient.request(EmptyResponse.self, at: PaymentAPI.submit(paymentId: paymentId, signature: signature))
    }
}

