import Foundation

struct Base32Encoder {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    
    static func encode(_ data: Data) -> String {
        var result = ""
        var bits = 0
        var buffer = 0
        
        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            
            while bits >= 5 {
                bits -= 5
                let index = (buffer >> bits) & 0x1F
                result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
            }
        }
        
        if bits > 0 {
            let index = (buffer << (5 - bits)) & 0x1F
            result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
        }
        
        return result
    }
} 