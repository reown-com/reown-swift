import Combine
import Foundation
import ReownWalletKit
import WalletConnectNotify
import HTTPClient

final class WalletInteractor {
    var sessionsPublisher: AnyPublisher<[Session], Never> {
        return WalletKit.instance.sessionsPublisher
    }

    func getSessions() -> [Session] {
        return WalletKit.instance.getSessions()
    }
    
    func pair(uri: WalletConnectURI) async throws {
        try await WalletKit.instance.pair(uri: uri)
    }
    
    func disconnectSession(session: Session) async throws {
        try await WalletKit.instance.disconnect(topic: session.topic)
    }

    func getPendingRequests() -> [(request: Request, context: VerifyContext?)] {
        WalletKit.instance.getPendingRequests()
    }
    
    func createPayment(merchantId: String, refId: String, amount: Int, currency: String) async throws -> String {
        let httpClient = HTTPNetworkClient(host: "pay-mvp-core-worker.walletconnect-v1-bridge.workers.dev")
        
        // Define a struct for the body to ensure proper encoding
        struct PaymentBody: Codable {
            let merchantId: String
            let refId: String
            let amount: Int
            let currency: String
        }
        
        let bodyStruct = PaymentBody(merchantId: merchantId, refId: refId, amount: amount, currency: currency)
        let data = try JSONEncoder().encode(bodyStruct)
        
        // Log request details
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Payment Create Request Body: \(jsonString)")
        }
        
        struct StartResponse: Codable {
            let paymentId: String
        }
        
        struct StartPaymentAPI: HTTPService {
            let bodyData: Data
            
            var path: String { "/start" }
            var method: HTTPMethod { .post }
            var body: Data? { bodyData }
            var queryParameters: [String : String]? { nil }
            // Removing explicit Content-Type header here as HTTPService.resolve automatically adds it
            // and having duplicates or incorrect casing might be an issue for some servers.
            // However, checking HTTPService.resolve, it ADDS it.
            // Let's try NOT overriding it in additionalHeaderFields since resolve adds it.
            var additionalHeaderFields: [String : String]? { nil }
            var scheme: String { "https" }
        }
        
        let api = StartPaymentAPI(bodyData: data)
        print("Sending request to host: pay-mvp-core-worker.walletconnect-v1-bridge.workers.dev path: \(api.path)")
        
        let response = try await httpClient.request(StartResponse.self, at: api)
        return response.paymentId
    }
}
