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
            let body = ["paymentId": paymentId, "address": address]
            return try? JSONEncoder().encode(body)
        case .submit(let paymentId, let signature):
            let body = ["paymentId": paymentId, "signature": signature]
            return try? JSONEncoder().encode(body)
        }
    }

    var queryParameters: [String : String]? {
        return nil
    }

    var additionalHeaderFields: [String : String]? {
        return ["Content-Type": "application/json"]
    }

    var scheme: String {
        return "https"
    }
}

