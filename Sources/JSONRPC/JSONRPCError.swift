public struct JSONRPCError: Error, Equatable, Codable {
    public let code: Int
    public let message: String
    public let data: AnyCodable?
    public var rpcCode: JSONRPCErrorCode? {
        return JSONRPCErrorCode(rawValue: code)
    }

    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(Int.self, forKey: .code)
        self.message = try container.decode(String.self, forKey: .message)
        self.data = try container.decodeIfPresent(AnyCodable.self, forKey: .data)
    }
}

public extension JSONRPCError {
    static let parseError = JSONRPCError(code: -32700, message: "An error occurred on the server while parsing the JSON text.")
    static let invalidRequest = JSONRPCError(code: -32600, message: "The JSON sent is not a valid Request object.")
    static let methodNotFound = JSONRPCError(code: -32601, message: "The method does not exist / is not available.")
    static let methodNotSupported = JSONRPCError(code: -32004, message: "The method is not supported by the wallet.")
    static let invalidParams = JSONRPCError(code: -32602, message: "Invalid method parameter(s).")
    static let internalError = JSONRPCError(code: -32603, message: "Internal JSON-RPC error.")
    
    static let userRejectedRequest = JSONRPCError(code: 4001, message: "User rejected the request.")
    static let unsupportedChain = JSONRPCError(code: 4902, message: "Unsupported chain. Please add the chain using wallet_addEthereumChain.")
}

public enum JSONRPCErrorCode: Int {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case methodNotSupported = -32004
    case invalidParams = -32602
    case internalError = -32603
    
    case userRejectedRequest = 4001
    case unsupportedChain = 4902
}
