import Foundation
import HTTPClient

enum PaymentAPI: HTTPService {
    case getPaymentInfo(paymentId: String)
    case buildPayment(paymentId: String, address: String)
    case submit(paymentId: String, signature: String)

    var path: String {
        switch self {
        case .getPaymentInfo(let paymentId):
            return "/getPaymentInfo/\(paymentId)"
        case .buildPayment:
            return "/buildPayment"
        case .submit:
            return "/submit"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getPaymentInfo:
            return .get
        case .buildPayment, .submit:
            return .post
        }
    }

    var body: Data? {
        switch self {
        case .getPaymentInfo:
            return nil
        case .buildPayment(let paymentId, let address):
            struct BuildPaymentBody: Codable {
                let paymentId: String
                let address: String
            }
            let body = BuildPaymentBody(paymentId: paymentId, address: address)
            return try? JSONEncoder().encode(body)
        case .submit(let paymentId, let signature):
            struct SubmitPaymentBody: Codable {
                let paymentId: String
                let signature: String
            }
            let body = SubmitPaymentBody(paymentId: paymentId, signature: signature)
            return try? JSONEncoder().encode(body)
        }
    }

    var queryParameters: [String : String]? {
        return nil
    }

    var additionalHeaderFields: [String : String]? {
        // Content-Type is already added by HTTPService.resolve
        return nil
    }

    var scheme: String {
        return "https"
    }
}
