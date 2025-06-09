//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-blake2 open source project
//
// Copyright (c) 2023 Timo Zacherl
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.Data
import protocol Foundation.DataProtocol

/// An implementation of BLAKE2b hashing.
///
/// You can compute the digest by calling the static
/// ``hash(data:key:digestLength:salt:)`` method once.
/// Alternatively, if the data you want to hash is too large to fit in
/// memory, you can compute the digest iteratively by creating a
/// new hash instance, calling the ``update(data:)`` method
/// repeatedly with blocks of data, and then calling the
/// ``finalize()`` method to get the result.
///
/// The implementation is based on
/// [RFC7693](https://datatracker.ietf.org/doc/html/rfc7693).
public struct BLAKE2b: Sendable {
    /// The default length of the computed digest.
    public static let defaultDigestLength = 64

    @usableFromInline
    enum Constants {
        @usableFromInline
        static let BLOCKBYTES = 128
        @usableFromInline
        static let KEYBYTES = 64
        @usableFromInline
        static let SALTBYTES = 16
        @usableFromInline
        static let PERSONALBYTES = 16
    }

    @usableFromInline
    struct State: Sendable {
        @usableFromInline
        var buf: [UInt8]
        @usableFromInline
        var h: [UInt64]
        @usableFromInline
        var t: [UInt64]
        @usableFromInline
        var f: [UInt64]
        /// Pointer in ``buf``.
        @usableFromInline
        var c: Int
        @usableFromInline
        var digestLength: Int

        @usableFromInline
        init() {
            self.buf = .init(repeating: 0, count: Constants.BLOCKBYTES)
            self.h = .init(repeating: 0, count: 8)
            self.t = .init(repeating: 0, count: 2)
            self.f = .init(repeating: 0, count: 2)
            self.c = 0
            self.digestLength = 0
        }
    }

    @usableFromInline
    static let parameterBlock: [UInt8] = [
        0, 0, 0, 0, //  0: outlen, keylen, fanout, depth
        0, 0, 0, 0, //  4: leaf length, sequential mode
        0, 0, 0, 0, //  8: node offset
        0, 0, 0, 0, // 12: node offset
        0, 0, 0, 0, // 16: node depth, inner length, rfu
        0, 0, 0, 0, // 20: rfu
        0, 0, 0, 0, // 24: rfu
        0, 0, 0, 0, // 28: rfu
        0, 0, 0, 0, // 32: salt
        0, 0, 0, 0, // 36: salt
        0, 0, 0, 0, // 40: salt
        0, 0, 0, 0, // 44: salt
        0, 0, 0, 0, // 48: personal
        0, 0, 0, 0, // 52: personal
        0, 0, 0, 0, // 56: personal
        0, 0, 0, 0, // 60: personal
    ]

    @usableFromInline
    static let iv: [UInt64] = [
        0x6a09e667f3bcc908, 0xbb67ae8584caa73b,
        0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
        0x510e527fade682d1, 0x9b05688c2b3e6c1f,
        0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
    ]

    @usableFromInline
    static let sigma: [[UInt8]] = [
        [  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 ],
        [ 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 ],
        [ 11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4 ],
        [  7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8 ],
        [  9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13 ],
        [  2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9 ],
        [ 12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11 ],
        [ 13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10 ],
        [  6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5 ],
        [ 10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13 , 0 ],
        [  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 ],
        [ 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 ]
    ]

    @usableFromInline
    var state: State! // this is guaranteed to be present

    /// Creates a BLAKE2b hash function.
    ///
    /// Initialize a new hash function by calling this method if you want to
    /// hash the data iteratively, such as when you don't have a buffer large
    /// enough to hold all the data at once. Provide data blocks to the hash
    /// function using the ``update(data:)`` method. After providing
    /// all the data, call ``finalize()`` to get the digest.
    ///
    /// If your data fits into a single buffer, you can use the
    /// ``hash(data:key:digestLength:salt:)`` method instead,
    /// to compute the digest in a single call.
    ///
    /// - Parameters:
    ///   - key: An optional key, used to compute the digest. It's byte count has to be less or equal `64`.
    ///   - digestLength: The length in bytes, must be within the range `1...64`. Defaults to `64`.
    ///   - salt: An optional salt, its length must be exactly `16` bytes.
    /// - Throws: ``BLAKE2Error``, if one of the parameters has an invalid length.
    @inlinable
    public init<K: DataProtocol, S: DataProtocol>(
        key: K? = Optional<Data>.none,
        digestLength: Int = BLAKE2b.defaultDigestLength,
        salt: S? = Optional<Data>.none
    ) throws {
        try self.initialize(
            digestLength: digestLength,
            key: key,
            salt: salt,
            personal: Optional<Data>.none
        )
    }

    @inlinable
    mutating func incrementCounter(by inc: UInt64) {
        self.state.t[0] += inc
        self.state.t[1] += self.state.t[0] < inc ? 1 : 0
    }

    @inlinable
    mutating func compress() {
        @inline(__always)
        func g(
            _ r: Int,
            _ i: Int,
            _ a: inout UInt64,
            _ b: inout UInt64,
            _ c: inout UInt64,
            _ d: inout UInt64
        ) {
            a = a &+ b &+ m[Int(BLAKE2b.sigma[r][2 * i + 0])]
            d = rotr64(d ^ a, 32)
            c = c &+ d
            b = rotr64(b ^ c, 24)
            a = a &+ b &+ m[Int(BLAKE2b.sigma[r][2 * i + 1])]
            d = rotr64(d ^ a, 16)
            c = c &+ d
            b = rotr64(b ^ c, 63)
        }

        @inline(__always)
        func round(_ r: Int) {
            v.withUnsafeMutableBufferPointer { p in
                g(r, 0, &p[0], &p[4], &p[ 8], &p[12])
                g(r, 1, &p[1], &p[5], &p[ 9], &p[13])
                g(r, 2, &p[2], &p[6], &p[10], &p[14])
                g(r, 3, &p[3], &p[7], &p[11], &p[15])
                g(r, 4, &p[0], &p[5], &p[10], &p[15])
                g(r, 5, &p[1], &p[6], &p[11], &p[12])
                g(r, 6, &p[2], &p[7], &p[ 8], &p[13])
                g(r, 7, &p[3], &p[4], &p[ 9], &p[14])
            }
        }


        var m = [UInt64](repeating: 0, count: 16)
        var v = [UInt64](repeating: 0, count: 16)

        for i in 0..<16 {
            m[i] = load64(self.state.buf, i: i * MemoryLayout<UInt64>.size)
        }

        for i in 0..<8 {
            v[i] = self.state.h[i]
        }

        v[8] =  Self.iv[0]
        v[9] =  Self.iv[1]
        v[10] = Self.iv[2]
        v[11] = Self.iv[3]
        v[12] = Self.iv[4] ^ self.state.t[0]
        v[13] = Self.iv[5] ^ self.state.t[1]
        v[14] = Self.iv[6] ^ self.state.f[0]
        v[15] = Self.iv[7] ^ self.state.f[1]

        round( 0)
        round( 1)
        round( 2)
        round( 3)
        round( 4)
        round( 5)
        round( 6)
        round( 7)
        round( 8)
        round( 9)
        round(10)
        round(11)

        for i in 0..<8 {
            self.state.h[i] = self.state.h[i] ^ v[i] ^ v[i + 8]
        }
    }

    @inlinable
    mutating func initialize<K: DataProtocol, S: DataProtocol, P: DataProtocol>(
        digestLength: Int,
        key: K?,
        salt: S?,
        personal: P?
    ) throws {
        guard
            digestLength != 0 && digestLength <= Self.defaultDigestLength
        else {
            throw BLAKE2Error.incorrectParameterSize
        }
        guard key?.count ?? 0 <= Constants.KEYBYTES else {
            throw BLAKE2Error.incorrectKeySize
        }
        guard salt?.count ?? Constants.SALTBYTES == Constants.SALTBYTES else {
            throw BLAKE2Error.incorrectParameterSize
        }
        guard
            personal?.count ?? Constants.PERSONALBYTES == Constants.SALTBYTES
        else {
            throw BLAKE2Error.incorrectParameterSize
        }

        var ctx = State()
        ctx.digestLength = digestLength
        var parameterBlock = Self.parameterBlock
        parameterBlock[0] = UInt8(digestLength)
        if let key {
            parameterBlock[1] = UInt8(key.count)
        }
        parameterBlock[2] = 1 // fanout
        parameterBlock[3] = 1 // depth
        if let salt {
            parameterBlock[32..<(32 + salt.count)] = ArraySlice(salt)
        }
        if let personal {
            parameterBlock[48..<(48 + personal.count)] = ArraySlice(personal)
        }

        // init hash state
        for i in 0..<8 {
            ctx.h[i] = Self.iv[i] ^
                load64(parameterBlock, i: i * MemoryLayout<UInt64>.size)
        }

        self.state = ctx

        // key hash, if needed
        if let key, !key.isEmpty {
            self.update(data: key)
            self.state.c = Constants.BLOCKBYTES
        }
    }

    /// Incrementally updates the hash function with the contents of the
    /// buffer.
    ///
    /// Call this method one or more times to provide data to the hash
    /// function in blocks. After providing the last block of data, call the
    /// ``finalize()`` method to get the computed digest. Don't call the
    /// update method again after finalizing the hash function.
    ///
    /// - Parameter data: The next block of data for the ongoing
    /// digest calculation.
    @inlinable
    public mutating func update<D: DataProtocol>(data: D) {
        for i in data.indices {
            if self.state.c == Constants.BLOCKBYTES {
                // buffer full?
                self.incrementCounter(by: UInt64(Constants.BLOCKBYTES))
                self.compress()
                self.state.c = 0
            }
            self.state.buf[self.state.c] = data[i]
            self.state.c += 1
        }
    }
    
    /// Finalizes the hash function and returns the computed digest.
    ///
    /// Call this method after you provide the hash function with all the
    /// data to hash by making one or more calls to the ``update(data:)``
    /// method. After finalizing the hash function, discard it. To compute a new
    ///  digest, create a new hash function with a call to the
    ///  ``init(key:digestLength:salt:)`` method.
    ///
    /// - Returns: The computed digest of the data.
    public mutating func finalize() -> Data {
        // mark last block offset
        self.incrementCounter(by: UInt64(self.state.c))

        while self.state.c < Constants.BLOCKBYTES {
            self.state.buf[self.state.c] = 0
            self.state.c += 1
        }

        // indicate last block
        self.state.f[0] = UInt64.max
        self.compress()

        var out = Data(repeating: 0, count: self.state.digestLength)
        for i in 0..<self.state.digestLength {
            out[i] = UInt8((self.state.h[i >> 3] >> (8 * (i & 7))) & 0xFF)
        }
        return out
    }

    /// Computes the BLAKE2b digest of the bytes in the given data and
    /// returns the computed digest.
    ///
    /// Use this method if all your data fits into a single data instance. If
    /// the data you want to hash is too large, initialize a hash function and
    /// use the ``update(data:)`` and ``finalize()`` methods to
    /// compute the digest in blocks.
    ///
    /// Per the specification any `digestLength` between `1` and `64` is supported, although the
    /// following map might help to decide on what to use:
    /// - **64**: BLAKE2b-512
    /// - **48**: BLAKE2b-384
    /// - **32**: BLAKE2b-256
    ///
    /// - Parameters:
    ///   - data: The data to be hashed.
    ///   - key: An optional key, used to compute the digest. It's byte count has to be less or equal `64`.
    ///   - digestLength: The length in bytes, must be within the range `1...64`. Defaults to `64`.
    ///   - salt: An optional salt, its length must be exactly `16` bytes.
    /// - Returns: The computed digest of the data in the specified `digestLength`.
    /// - Throws: ``BLAKE2Error``, if one of the parameters has an invalid length.
    @inlinable
    public static func hash<D: DataProtocol, K: DataProtocol, S: DataProtocol>(
        data: D,
        key: K? = Optional<Data>.none,
        digestLength: Int = Self.defaultDigestLength,
        salt: S? = Optional<Data>.none
    ) throws -> Data {
        var hasher = try BLAKE2b(
            key: key,
            digestLength: digestLength,
            salt: salt
        )
        hasher.update(data: data)
        return hasher.finalize()
    }
}

@inlinable
func load64(_ src: [UInt8], i: Int) -> UInt64 {
    let p = src[i..<(i + 8)]
    // had to split one out so the compiler can type check in time
    let p1 = UInt64(p[i + 0]) << 0
    return p1 |
    (UInt64(p[i + 1]) <<  8) |
    (UInt64(p[i + 2]) << 16) |
    (UInt64(p[i + 3]) << 24) |
    (UInt64(p[i + 4]) << 32) |
    (UInt64(p[i + 5]) << 40) |
    (UInt64(p[i + 6]) << 48) |
    (UInt64(p[i + 7]) << 56)
}

@inlinable
func rotr64(_ w: UInt64, _ c: UInt8) -> UInt64 {
    (w >> c) | (w << (64 - c))
}

// MARK: - Util

/// Cryptography errors used by BLAKE2.
public enum BLAKE2Error: Error {
    /// The key size is incorrect.
    case incorrectKeySize

    /// The parameter size is incorrect.
    case incorrectParameterSize
}
