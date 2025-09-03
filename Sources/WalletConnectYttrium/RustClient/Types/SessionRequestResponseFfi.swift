import Foundation
import YttriumWrapper

// MARK: - Converters

extension RPCResult {
    func toYttriumFfiResponse(id: RPCID) throws -> SessionRequestJsonRpcResponseFfi {
        let idUInt = UInt64(bitPattern: id.integer)
        switch self {
        case .response(let anyCodable):
            let data = try JSONEncoder().encode(anyCodable)
            let jsonString = String(data: data, encoding: .utf8) ?? "null"
            let res = SessionRequestJsonRpcResultResponseFfi(id: idUInt, jsonrpc: "2.0", result: jsonString)
            return .result(res)
        case .error(let jsonError):
            let err = SessionRequestJsonRpcErrorResponseFfi(id: idUInt, jsonrpc: "2.0", error: jsonError.message)
            return .error(err)
        }
    }
}


