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
        print("[PaymentService] Getting payment info for paymentId: \(paymentId)")
        
        let api = PaymentAPI.getPaymentInfo(paymentId: paymentId)
        guard let request = api.resolve(for: "pay-mvp-core-worker.walletconnect-v1-bridge.workers.dev") else {
            throw NSError(domain: "PaymentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("[PaymentService] getPaymentInfo status code: \(httpResponse.statusCode)")
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        print("[PaymentService] getPaymentInfo raw response: \(responseString)")
        
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "PaymentService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "getPaymentInfo failed: \(responseString)"])
        }
        
        let result = try JSONDecoder().decode(PaymentInfo.self, from: data)
        print("[PaymentService] PaymentInfo parsed: paymentId=\(result.paymentId), amount=\(result.amount), referenceId=\(result.referenceId), status=\(result.status)")
        return result
    }

    func buildPayment(paymentId: String, address: String) async throws -> PaymentRPC {
        return try await httpClient.request(PaymentRPC.self, at: PaymentAPI.buildPayment(paymentId: paymentId, address: address))
    }

    func submit(paymentId: String, signature: String) async throws {
        print("[PaymentService] Submitting to /submit endpoint")
        print("[PaymentService] paymentId: \(paymentId)")
        print("[PaymentService] signature (authorization): \(signature)")
        
        let api = PaymentAPI.submit(paymentId: paymentId, signature: signature)
        if let body = api.body, let bodyString = String(data: body, encoding: .utf8) {
            print("[PaymentService] Request body: \(bodyString)")
        }
        
        // Make request manually to log response
        guard let request = api.resolve(for: "pay-mvp-core-worker.walletconnect-v1-bridge.workers.dev") else {
            throw NSError(domain: "PaymentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("[PaymentService] Response status code: \(httpResponse.statusCode)")
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        print("[PaymentService] Response body: \(responseString)")
        
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "PaymentService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Submit failed with status \(statusCode): \(responseString)"])
        }
        
        print("[PaymentService] Submit successful!")
    }
}

