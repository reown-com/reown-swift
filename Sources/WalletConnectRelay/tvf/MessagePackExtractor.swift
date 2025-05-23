import Foundation

struct MessagePackExtractor {
    static func extractCanonicalTransaction(from data: Data) -> Data? {
        var index = data.startIndex
        guard let mapCount = readMapCount(data, &index) else { return nil }
        for _ in 0..<mapCount {
            guard let key = readString(data, &index) else { return nil }
            let valueStart = index
            guard skip(data, &index) else { return nil }
            let valueRange = valueStart..<index
            if key == "txn" {
                return data.subdata(in: valueRange)
            }
        }
        return nil
    }

    private static func readMapCount(_ data: Data, _ index: inout Int) -> Int? {
        guard index < data.count else { return nil }
        let byte = data[index]
        index += 1
        if byte >= 0x80 && byte <= 0x8f { return Int(byte & 0x0f) }
        if byte == 0xde {
            guard index + 2 <= data.count else { return nil }
            let count = Int(data[index]) << 8 | Int(data[index+1])
            index += 2
            return count
        }
        if byte == 0xdf {
            guard index + 4 <= data.count else { return nil }
            let count = Int(data[index]) << 24 | Int(data[index+1]) << 16 | Int(data[index+2]) << 8 | Int(data[index+3])
            index += 4
            return count
        }
        return nil
    }

    private static func readString(_ data: Data, _ index: inout Int) -> String? {
        guard index < data.count else { return nil }
        let byte = data[index]
        index += 1
        var length: Int
        switch byte {
        case 0xa0...0xbf:
            length = Int(byte & 0x1f)
        case 0xd9:
            guard index + 1 <= data.count else { return nil }
            length = Int(data[index])
            index += 1
        case 0xda:
            guard index + 2 <= data.count else { return nil }
            length = Int(data[index]) << 8 | Int(data[index+1])
            index += 2
        case 0xdb:
            guard index + 4 <= data.count else { return nil }
            length = Int(data[index]) << 24 | Int(data[index+1]) << 16 | Int(data[index+2]) << 8 | Int(data[index+3])
            index += 4
        default:
            return nil
        }
        guard index + length <= data.count else { return nil }
        let strData = data.subdata(in: index..<index+length)
        index += length
        return String(data: strData, encoding: .utf8)
    }

    private static func skip(_ data: Data, _ index: inout Int) -> Bool {
        guard index < data.count else { return false }
        let byte = data[index]
        index += 1
        switch byte {
        case 0x00...0x7f, 0xe0...0xff, 0xc0, 0xc2, 0xc3:
            return true
        case 0xcc, 0xd0:
            index += 1
            return index <= data.count
        case 0xcd, 0xd1, 0xca:
            index += 2
            return index <= data.count
        case 0xce, 0xd2, 0xcb:
            index += 4
            return index <= data.count
        case 0xcf, 0xd3:
            index += 8
            return index <= data.count
        case 0xa0...0xbf:
            index += Int(byte & 0x1f)
            return index <= data.count
        case 0xd9, 0xc4:
            guard index + 1 <= data.count else { return false }
            let len = Int(data[index])
            index += 1 + len
            return index <= data.count
        case 0xda, 0xc5:
            guard index + 2 <= data.count else { return false }
            let len = Int(data[index]) << 8 | Int(data[index+1])
            index += 2 + len
            return index <= data.count
        case 0xdb, 0xc6:
            guard index + 4 <= data.count else { return false }
            let len = Int(data[index]) << 24 | Int(data[index+1]) << 16 | Int(data[index+2]) << 8 | Int(data[index+3])
            index += 4 + len
            return index <= data.count
        case 0x90...0x9f:
            let count = Int(byte & 0x0f)
            for _ in 0..<count { if !skip(data, &index) { return false } }
            return true
        case 0xdc:
            guard let count = readUInt16(data, &index) else { return false }
            for _ in 0..<count { if !skip(data, &index) { return false } }
            return true
        case 0xdd:
            guard let count = readUInt32(data, &index) else { return false }
            for _ in 0..<count { if !skip(data, &index) { return false } }
            return true
        case 0x80...0x8f:
            let count = Int(byte & 0x0f)
            for _ in 0..<count { if !skip(data, &index) || !skip(data, &index) { return false } }
            return true
        case 0xde:
            guard let count = readUInt16(data, &index) else { return false }
            for _ in 0..<count { if !skip(data, &index) || !skip(data, &index) { return false } }
            return true
        case 0xdf:
            guard let count = readUInt32(data, &index) else { return false }
            for _ in 0..<count { if !skip(data, &index) || !skip(data, &index) { return false } }
            return true
        default:
            return false
        }
    }

    private static func readUInt16(_ data: Data, _ index: inout Int) -> Int? {
        guard index + 2 <= data.count else { return nil }
        let val = Int(data[index]) << 8 | Int(data[index+1])
        index += 2
        return val
    }

    private static func readUInt32(_ data: Data, _ index: inout Int) -> Int? {
        guard index + 4 <= data.count else { return nil }
        let val = Int(data[index]) << 24 | Int(data[index+1]) << 16 | Int(data[index+2]) << 8 | Int(data[index+3])
        index += 4
        return val
    }
}
