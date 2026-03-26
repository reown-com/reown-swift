//
//  File.swift
//  reown
//
//  Created by BARTOSZ ROZWARSKI on 13/08/2025.
//

import Foundation
import CryptoKit

extension Data {
    public func sha256() -> Data {
        let digest = SHA256.hash(data: self)
        return digest.withUnsafeBytes { buffer in
            Data(buffer)
        }
    }
}
