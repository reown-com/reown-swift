import Foundation

public enum RPCResult: Codable, Equatable {
    enum Errors: Error { case decoding }

    case response(AnyCodable)
    case error(JSONRPCError)

    public var value: Codable {
        switch self {
        case .response(let value): return value
        case .error(let value):    return value
        }
    }

    // WalletConnect-style envelope: { "code": <int>, "message": "<json string>" }
    private struct WCEnvelope: Decodable {
        let code: Int
        let message: String
    }

    public init(from decoder: Decoder) throws {
        // 2) WalletConnect envelope with embedded JSON-RPC error in `message`
        if let env = try? WCEnvelope(from: decoder),
           let data = env.message.data(using: .utf8),
           let rpcError = try? JSONDecoder().decode(JSONRPCError.self, from: data) {
            self = .error(rpcError)
            return
        }

        // 3) Anything else => .response(AnyCodable)
        if let any = try? AnyCodable(from: decoder) {
            self = .response(any)
            return
        }

        throw Errors.decoding
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .error(let value):
            try value.encode(to: encoder)

        case .response(let value):
            try value.encode(to: encoder)
        }
    }
}
