import Foundation

enum BlockchainAPI: HTTPService {
    struct GetIdentityParams {
        let address: String
        let chainId: String
        let projectId: String
        let clientId: String?
    }
    
    case getIdentity(params: GetIdentityParams)

    var path: String {
        switch self {
        case let .getIdentity(params): return "/v1/identity/\(params.address)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getIdentity: return .get
        }
    }

    var body: Data? {
        nil
    }

    var queryParameters: [String: String]? {
        switch self {
        case let .getIdentity(params):
            var parameters: [String: String] = [
                "projectId": params.projectId,
                "chainId": params.chainId
            ]
            if let clientId = params.clientId {
                parameters["clientId"] = clientId
            }
            return parameters
        }
    }

    var scheme: String {
        return "https"
    }

    var additionalHeaderFields: [String: String]? {
        nil
    }
}
