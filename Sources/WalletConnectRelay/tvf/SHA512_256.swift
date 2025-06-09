import Foundation

struct SHA512_256 {
    static func hash(data: Data) -> Data {
        // SHA-512/256 uses the same algorithm as SHA-512 but with different initial hash values
        // and the output is truncated to 256 bits (32 bytes)
        
        // Initial hash values for SHA-512/256 (specified in RFC 6234)
        var h0: UInt64 = 0x22312194FC2BF72C
        var h1: UInt64 = 0x9F555FA3C84C64C2
        var h2: UInt64 = 0x2393B86B6F53B151
        var h3: UInt64 = 0x963877195940EABD
        var h4: UInt64 = 0x96283EE2A88EFFE3
        var h5: UInt64 = 0xBE5E1E2553863992
        var h6: UInt64 = 0x2B0199FC2C85B8AA
        var h7: UInt64 = 0x0EB72DDC81C52CA2
        
        // SHA-512 constants
        let k: [UInt64] = [
            0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
            0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
            0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
            0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
            0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
            0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
            0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
            0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
            0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
            0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
            0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
            0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
            0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
            0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
            0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
            0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
            0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
            0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
            0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
            0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
        ]
        
        // Pre-processing: adding a single 1 bit
        var message = Array(data)
        let msgLength = message.count
        message.append(0x80)
        
        // Pre-processing: padding with zeros
        while (message.count % 128) != 112 {
            message.append(0x00)
        }
        
        // Append original length in bits mod 2^128 as 128-bit big-endian integer
        let bitLength = UInt64(msgLength * 8)
        for i in 0..<8 {
            message.append(0x00) // high 64 bits are 0
        }
        for i in 0..<8 {
            message.append(UInt8((bitLength >> (56 - i * 8)) & 0xFF))
        }
        
        // Process message in successive 1024-bit chunks
        for chunk in stride(from: 0, to: message.count, by: 128) {
            var w = [UInt64](repeating: 0, count: 80)
            
            // Break chunk into sixteen 64-bit big-endian words
            for i in 0..<16 {
                let offset = chunk + i * 8
                // Break up the complex expression to help the compiler
                let byte0 = UInt64(message[offset]) << 56
                let byte1 = UInt64(message[offset + 1]) << 48
                let byte2 = UInt64(message[offset + 2]) << 40
                let byte3 = UInt64(message[offset + 3]) << 32
                let byte4 = UInt64(message[offset + 4]) << 24
                let byte5 = UInt64(message[offset + 5]) << 16
                let byte6 = UInt64(message[offset + 6]) << 8
                let byte7 = UInt64(message[offset + 7])
                
                w[i] = byte0 | byte1 | byte2 | byte3 | byte4 | byte5 | byte6 | byte7
            }
            
            // Extend the sixteen 64-bit words into eighty 64-bit words
            for i in 16..<80 {
                let s0 = rightRotate64(w[i-15], 1) ^ rightRotate64(w[i-15], 8) ^ (w[i-15] >> 7)
                let s1 = rightRotate64(w[i-2], 19) ^ rightRotate64(w[i-2], 61) ^ (w[i-2] >> 6)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }
            
            // Initialize hash value for this chunk
            var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7
            
            // Main loop
            for i in 0..<80 {
                let s1 = rightRotate64(e, 14) ^ rightRotate64(e, 18) ^ rightRotate64(e, 41)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rightRotate64(a, 28) ^ rightRotate64(a, 34) ^ rightRotate64(a, 39)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                
                h = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }
            
            // Add this chunk's hash to result so far
            h0 = h0 &+ a
            h1 = h1 &+ b
            h2 = h2 &+ c
            h3 = h3 &+ d
            h4 = h4 &+ e
            h5 = h5 &+ f
            h6 = h6 &+ g
            h7 = h7 &+ h
        }
        
        // Produce the final hash value (first 256 bits only for SHA-512/256)
        var result = Data()
        result.append(contentsOf: uint64ToBytes(h0))
        result.append(contentsOf: uint64ToBytes(h1))
        result.append(contentsOf: uint64ToBytes(h2))
        result.append(contentsOf: uint64ToBytes(h3))
        
        return result
    }
    
    private static func rightRotate64(_ value: UInt64, _ amount: Int) -> UInt64 {
        return (value >> amount) | (value << (64 - amount))
    }
    
    private static func uint64ToBytes(_ value: UInt64) -> [UInt8] {
        return [
            UInt8((value >> 56) & 0xFF),
            UInt8((value >> 48) & 0xFF),
            UInt8((value >> 40) & 0xFF),
            UInt8((value >> 32) & 0xFF),
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }
} 