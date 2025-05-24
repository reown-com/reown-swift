import Foundation

struct MessagePackExtractor {
    static func extractCanonicalTransaction(from data: Data) -> Data? {
        do {
            let (value, _) = try unpack(data)
            guard case let .map(root) = value else { return nil }
            guard let txnValue = root[MessagePackValue("txn")] else { return nil }
            return canonicalPack(txnValue)
        } catch {
            return nil
        }
    }

    private static func canonicalPack(_ value: MessagePackValue) -> Data {
        switch value {
        case .map(let dict):
            var result = Data()
            let count = UInt32(dict.count)
            if count <= 0x0f {
                result.append(0x80 | UInt8(count))
            } else if count <= 0xffff {
                result.append(0xde)
                result.append(packInteger(UInt64(count), parts: 2))
            } else {
                result.append(0xdf)
                result.append(packInteger(UInt64(count), parts: 4))
            }
            let sortedKeys = dict.keys.sorted { ($0.stringValue ?? "") < ($1.stringValue ?? "") }
            for key in sortedKeys {
                result.append(canonicalPack(key))
                if let val = dict[key] {
                    result.append(canonicalPack(val))
                }
            }
            return result
        case .array(let array):
            var result = Data()
            let count = UInt32(array.count)
            if count <= 0x0f {
                result.append(0x90 | UInt8(count))
            } else if count <= 0xffff {
                result.append(0xdc)
                result.append(packInteger(UInt64(count), parts: 2))
            } else {
                result.append(0xdd)
                result.append(packInteger(UInt64(count), parts: 4))
            }
            for v in array {
                result.append(canonicalPack(v))
            }
            return result
        default:
            return pack(value)
        }
    }
}
