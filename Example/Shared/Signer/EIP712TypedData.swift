import Foundation
import BigInt
import CryptoSwift

/// Minimal EIP-712 typed-data hasher.
///
/// Parses a `{types, primaryType, domain, message}` JSON object and produces the
/// 32-byte signing digest:
///   `keccak256(0x1901 || hashStruct("EIP712Domain", domain) || hashStruct(primaryType, message))`
///
/// Supports every EIP-712 encodable type we expect from merchant payment flows
/// (Permit2, ERC-3009, etc.): primitives (`address`, `bool`, `uint*`, `int*`,
/// `bytes`, `string`, `bytesN`), nested structs, and arrays (`T[]` / `T[N]`).
struct EIP712TypedData {
    struct Field {
        let name: String
        let type: String
    }

    let types: [String: [Field]]
    let primaryType: String
    let domain: Any
    let message: Any

    static func parse(jsonString: String) throws -> EIP712TypedData {
        guard let data = jsonString.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EIP712Error.invalidJSON
        }
        guard let typesRaw = root["types"] as? [String: [[String: Any]]] else {
            throw EIP712Error.missing("types")
        }
        guard let primary = root["primaryType"] as? String else {
            throw EIP712Error.missing("primaryType")
        }
        guard let domain = root["domain"] else { throw EIP712Error.missing("domain") }
        guard let message = root["message"] else { throw EIP712Error.missing("message") }

        var parsedTypes: [String: [Field]] = [:]
        for (name, fields) in typesRaw {
            parsedTypes[name] = fields.compactMap { f -> Field? in
                guard let n = f["name"] as? String, let t = f["type"] as? String else { return nil }
                return Field(name: n, type: t)
            }
        }
        return EIP712TypedData(
            types: parsedTypes,
            primaryType: primary,
            domain: domain,
            message: message
        )
    }

    func digest() throws -> [UInt8] {
        let domainSep = try hashStruct(type: "EIP712Domain", data: domain)
        let messageHash = try hashStruct(type: primaryType, data: message)
        var buf: [UInt8] = [0x19, 0x01]
        buf.append(contentsOf: domainSep)
        buf.append(contentsOf: messageHash)
        return Self.keccak256(buf)
    }

    // MARK: - Struct + type encoding

    private func hashStruct(type: String, data: Any) throws -> [UInt8] {
        var buf = typeHash(of: type)
        buf.append(contentsOf: try encodeData(type: type, data: data))
        return Self.keccak256(buf)
    }

    private func typeHash(of type: String) -> [UInt8] {
        Self.keccak256(Array(encodeType(of: type).utf8))
    }

    private func encodeType(of type: String) -> String {
        var deps = dependencies(of: type, collected: Set([type]))
        deps.remove(type)
        let ordered = [type] + deps.sorted()
        return ordered.map { name -> String in
            let fields = types[name] ?? []
            let body = fields.map { "\($0.type) \($0.name)" }.joined(separator: ",")
            return "\(name)(\(body))"
        }.joined()
    }

    private func dependencies(of type: String, collected: Set<String>) -> Set<String> {
        guard let fields = types[type] else { return collected }
        var result = collected
        for f in fields {
            let base = Self.baseType(f.type)
            if types[base] != nil, !result.contains(base) {
                result.insert(base)
                result.formUnion(dependencies(of: base, collected: result))
            }
        }
        return result
    }

    private static func baseType(_ type: String) -> String {
        if let idx = type.firstIndex(of: "[") { return String(type[..<idx]) }
        return type
    }

    private func encodeData(type: String, data: Any) throws -> [UInt8] {
        guard let fields = types[type] else { throw EIP712Error.unknownType(type) }
        guard let dict = data as? [String: Any] else { throw EIP712Error.expectedObject(type) }
        var buf: [UInt8] = []
        for f in fields {
            let encoded = try encodeValue(type: f.type, value: dict[f.name])
            buf.append(contentsOf: encoded)
        }
        return buf
    }

    /// Encode a single value into its 32-byte EIP-712 word (or keccak256 of
    /// concatenated encodings for arrays / dynamic types).
    private func encodeValue(type: String, value: Any?) throws -> [UInt8] {
        if type.hasSuffix("]") {
            guard let openIdx = type.lastIndex(of: "[") else {
                throw EIP712Error.invalidType(type)
            }
            let inner = String(type[..<openIdx])
            guard let array = value as? [Any] else { throw EIP712Error.expectedArray(type) }
            var buf: [UInt8] = []
            for el in array {
                buf.append(contentsOf: try encodeValue(type: inner, value: el))
            }
            return Self.keccak256(buf)
        }

        if types[type] != nil {
            guard let value else { throw EIP712Error.missing(type) }
            return try hashStruct(type: type, data: value)
        }

        guard let value else { throw EIP712Error.missing(type) }
        switch type {
        case "address":
            return try encodeAddress(value)
        case "bool":
            return try encodeBool(value)
        case "string":
            let s = (value as? String) ?? ""
            return Self.keccak256(Array(s.utf8))
        case "bytes":
            let bytes = try parseBytes(value)
            return Self.keccak256(bytes)
        default:
            if type.hasPrefix("uint") {
                return try encodeUInt(value)
            }
            if type.hasPrefix("int") {
                return try encodeInt(value)
            }
            if type.hasPrefix("bytes") {
                let raw = try parseBytes(value)
                if raw.count > 32 { throw EIP712Error.invalidType(type) }
                return raw + Array(repeating: 0, count: 32 - raw.count)
            }
            throw EIP712Error.unknownType(type)
        }
    }

    private func encodeAddress(_ value: Any) throws -> [UInt8] {
        guard let s = value as? String else { throw EIP712Error.expectedString("address") }
        let hex = s.hasPrefix("0x") || s.hasPrefix("0X") ? String(s.dropFirst(2)) : s
        let bytes = [UInt8](hex: hex)
        guard bytes.count == 20 else { throw EIP712Error.invalidAddress(s) }
        return Array(repeating: 0, count: 12) + bytes
    }

    private func encodeBool(_ value: Any) throws -> [UInt8] {
        let flag: Bool
        if let b = value as? Bool { flag = b }
        else if let n = value as? NSNumber { flag = n.boolValue }
        else if let s = value as? String { flag = (s == "true" || s == "1") }
        else { throw EIP712Error.expectedBool }
        return Array(repeating: 0, count: 31) + [flag ? 1 : 0]
    }

    private func encodeUInt(_ value: Any) throws -> [UInt8] {
        let v = try parseBigUInt(value)
        let bytes = Array(v.serialize())
        guard bytes.count <= 32 else {
            throw EIP712Error.integerOutOfRange(String(describing: value))
        }
        return Array(repeating: 0, count: 32 - bytes.count) + bytes
    }

    private func encodeInt(_ value: Any) throws -> [UInt8] {
        let v = try parseBigInt(value)
        let modulus = BigInt(1) << 256
        let unsigned = v >= 0 ? v : (modulus + v)
        let bytes = Array(unsigned.magnitude.serialize())
        guard bytes.count <= 32 else {
            throw EIP712Error.integerOutOfRange(String(describing: value))
        }
        return Array(repeating: 0, count: 32 - bytes.count) + bytes
    }

    private func parseBigUInt(_ value: Any) throws -> BigUInt {
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
                let hex = String(trimmed.dropFirst(2))
                if hex.isEmpty { return 0 }
                guard let parsed = BigUInt(hex, radix: 16) else {
                    throw EIP712Error.invalidInteger(s)
                }
                return parsed
            }
            if trimmed.isEmpty { return 0 }
            guard let parsed = BigUInt(trimmed, radix: 10) else {
                throw EIP712Error.invalidInteger(s)
            }
            return parsed
        }
        if let n = value as? NSNumber {
            guard let parsed = BigUInt(n.stringValue, radix: 10) else {
                throw EIP712Error.invalidInteger(n.stringValue)
            }
            return parsed
        }
        throw EIP712Error.invalidInteger(String(describing: value))
    }

    private func parseBigInt(_ value: Any) throws -> BigInt {
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("-") {
                let rest = String(trimmed.dropFirst())
                guard let mag = BigUInt(rest, radix: 10) else {
                    throw EIP712Error.invalidInteger(s)
                }
                return -BigInt(mag)
            }
            return BigInt(try parseBigUInt(value))
        }
        if let n = value as? NSNumber {
            let str = n.stringValue
            if str.hasPrefix("-") {
                let rest = String(str.dropFirst())
                guard let mag = BigUInt(rest, radix: 10) else {
                    throw EIP712Error.invalidInteger(str)
                }
                return -BigInt(mag)
            }
            guard let mag = BigUInt(str, radix: 10) else {
                throw EIP712Error.invalidInteger(str)
            }
            return BigInt(mag)
        }
        throw EIP712Error.invalidInteger(String(describing: value))
    }

    private func parseBytes(_ value: Any) throws -> [UInt8] {
        guard let s = value as? String else { throw EIP712Error.expectedString("bytes") }
        let hex = s.hasPrefix("0x") || s.hasPrefix("0X") ? String(s.dropFirst(2)) : s
        if hex.isEmpty { return [] }
        return [UInt8](hex: hex)
    }

    private static func keccak256(_ bytes: [UInt8]) -> [UInt8] {
        SHA3(variant: .keccak256).calculate(for: bytes)
    }

    enum EIP712Error: Error, LocalizedError {
        case invalidJSON
        case missing(String)
        case unknownType(String)
        case invalidType(String)
        case expectedObject(String)
        case expectedArray(String)
        case expectedString(String)
        case expectedBool
        case invalidAddress(String)
        case invalidInteger(String)
        case integerOutOfRange(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON: return "Invalid typed-data JSON"
            case .missing(let f): return "Missing EIP-712 field: \(f)"
            case .unknownType(let t): return "Unknown EIP-712 type: \(t)"
            case .invalidType(let t): return "Invalid EIP-712 type: \(t)"
            case .expectedObject(let t): return "Expected object for type: \(t)"
            case .expectedArray(let t): return "Expected array for type: \(t)"
            case .expectedString(let t): return "Expected string value for type: \(t)"
            case .expectedBool: return "Expected bool value"
            case .invalidAddress(let a): return "Invalid address: \(a)"
            case .invalidInteger(let s): return "Invalid integer: \(s)"
            case .integerOutOfRange(let s): return "Integer out of uint256/int256 range: \(s)"
            }
        }
    }
}
