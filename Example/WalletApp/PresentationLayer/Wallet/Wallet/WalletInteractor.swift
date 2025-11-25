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
        let body = ["merchantId": merchantId, "refId": refId, "amount": amount, "currency": currency] as [String : Any]
        let data = try JSONSerialization.data(withJSONObject: body)
        
        struct StartResponse: Codable {
            let paymentId: String
        }
        
        struct StartPaymentAPI: HTTPService {
            let bodyData: Data
            
            var path: String { "/start" }
            var method: HTTPMethod { .post }
            var body: Data? { bodyData }
            var queryParameters: [String : String]? { nil }
            var additionalHeaderFields: [String : String]? { ["Content-Type": "application/json"] }
            var scheme: String { "https" }
        }
        
        let response = try await httpClient.request(StartResponse.self, at: StartPaymentAPI(bodyData: data))
        return response.paymentId
    }
}
