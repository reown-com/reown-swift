import Foundation

/// Minimal JSON-RPC client against WalletConnect's blockchain RPC.
/// Endpoint: https://rpc.walletconnect.org/v1/?chainId=<caip2>&projectId=<pid>
struct PayRPCClient {
    let chainId: String
    let projectId: String
    private let session: URLSession

    init(chainId: String, projectId: String, session: URLSession = .shared) {
        self.chainId = chainId
        self.projectId = projectId
        self.session = session
    }

    // MARK: - Typed convenience methods

    func gasPrice() async throws -> String {
        try await call(method: "eth_gasPrice", params: [])
    }

    func maxPriorityFeePerGas() async throws -> String {
        try await call(method: "eth_maxPriorityFeePerGas", params: [])
    }

    func getLatestBlock() async throws -> RPCBlock {
        try await call(method: "eth_getBlockByNumber", params: [.string("latest"), .bool(false)])
    }

    func estimateGas(_ tx: RPCTxRequest) async throws -> String {
        try await call(method: "eth_estimateGas", params: [.object(tx.toParams())])
    }

    func getTransactionCount(address: String, block: String = "pending") async throws -> String {
        try await call(method: "eth_getTransactionCount", params: [.string(address), .string(block)])
    }

    func sendRawTransaction(_ rawHex: String) async throws -> String {
        try await call(method: "eth_sendRawTransaction", params: [.string(rawHex)])
    }

    func getTransactionReceipt(hash: String) async throws -> RPCTransactionReceipt? {
        try await callOptional(method: "eth_getTransactionReceipt", params: [.string(hash)])
    }

    // MARK: - Generic RPC

    func call<T: Decodable>(method: String, params: [RPCParam]) async throws -> T {
        let data = try await send(method: method, params: params)
        let response = try JSONDecoder().decode(RPCResponse<T>.self, from: data)
        if let error = response.error {
            throw PayRPCError.rpc(code: error.code, message: error.message)
        }
        guard let result = response.result else {
            throw PayRPCError.emptyResult
        }
        return result
    }

    func callOptional<T: Decodable>(method: String, params: [RPCParam]) async throws -> T? {
        let data = try await send(method: method, params: params)
        let response = try JSONDecoder().decode(RPCResponse<T>.self, from: data)
        if let error = response.error {
            throw PayRPCError.rpc(code: error.code, message: error.message)
        }
        return response.result
    }

    private func send(method: String, params: [RPCParam]) async throws -> Data {
        guard var components = URLComponents(string: "https://rpc.walletconnect.org/v1/") else {
            throw PayRPCError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "chainId", value: chainId),
            URLQueryItem(name: "projectId", value: projectId)
        ]
        guard let url = components.url else { throw PayRPCError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RPCRequest(method: method, params: params)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PayRPCError.httpStatus(http.statusCode)
        }
        return data
    }
}

// MARK: - Request/response types

enum PayRPCError: Error, LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case rpc(code: Int, message: String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid RPC URL"
        case .httpStatus(let code): return "RPC HTTP \(code)"
        case .rpc(let code, let message): return "RPC error \(code): \(message)"
        case .emptyResult: return "RPC result was empty"
        }
    }
}

/// A JSON-RPC param that can be a string, bool, number, or a nested object (used for tx request).
enum RPCParam: Encodable {
    case string(String)
    case bool(Bool)
    case object([String: String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

private struct RPCRequest: Encodable {
    let jsonrpc = "2.0"
    let id = 1
    let method: String
    let params: [RPCParam]
}

struct RPCResponse<T: Decodable>: Decodable {
    let result: T?
    let error: RPCErrorBody?
}

struct RPCErrorBody: Decodable {
    let code: Int
    let message: String
}

struct RPCBlock: Decodable {
    let baseFeePerGas: String?
    let number: String?
}

struct RPCTransactionReceipt: Decodable {
    let status: String?
    let transactionHash: String?
    let blockNumber: String?
}

/// Transaction shape passed to `eth_estimateGas` — all fields hex-encoded.
struct RPCTxRequest {
    var from: String
    var to: String?
    var data: String?
    var value: String?

    func toParams() -> [String: String] {
        var dict: [String: String] = ["from": from]
        if let to { dict["to"] = to }
        if let data { dict["data"] = data }
        if let value { dict["value"] = value }
        return dict
    }
}
