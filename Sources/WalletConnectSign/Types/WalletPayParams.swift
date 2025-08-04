//
//  WalletPayParams.swift
//  reown
//
//  Created by BARTOSZ ROZWARSKI on 30/07/2025.
//
//  CAIP-122 Sign with X Support Added:
//  Now supports chain-agnostic authentication messages:
//  - Ethereum (eip155): "example.com wants you to sign in with your Ethereum account:"
//  - Bitcoin (bip122): "example.com wants you to sign in with your Bitcoin account:"
//  - Solana (solana): "example.com wants you to sign in with your Solana account:"
//

import Foundation

public struct PaymentOption: Codable, Equatable {
    public let asset: String
    public let amount: String
    public let recipient: String
    
    public init(asset: String, amount: String, recipient: String) {
        self.asset = asset
        self.amount = amount
        self.recipient = recipient
    }
}

public struct WalletPayParams: Codable, Equatable {
    public let version: String
    public let orderId: String?
    public let acceptedPayments: [PaymentOption]
    public let expiry: UInt64
    
    public init(version: String, orderId: String? = nil, acceptedPayments: [PaymentOption], expiry: UInt64) {
        self.version = version
        self.orderId = orderId
        self.acceptedPayments = acceptedPayments
        self.expiry = expiry
    }
}
