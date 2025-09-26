//
//  File.swift
//  reown
//
//  Created by BARTOSZ ROZWARSKI on 25/09/2025.
//

import Foundation


public class WalletKitRust {
    
    /// WalletKitRust client instance
    public static var instance: WalletKitRustClient = {
        guard let config = WalletKitRust.config else {
            fatalError("Error - you must call WalletKitRust.configure(_:) before accessing the shared instance.")
        }
        return WalletKitRustClientFactory.create(config: config, groupIdentifier: config.groupIdentifier)
    }()
    
    private static var config: Config?
    
    struct Config {
        let projectId: String
        let groupIdentifier: String
        let metadata: AppMetadata
    }
    
    private init() { }
    
    /// WalletKitRust instance configuration method.
    /// - Parameters:
    ///   - projectId: The project ID for the wallet connect
    static public func configure(
        projectId: String,
        groupIdentifier: String,
        metadata: AppMetadata
    ) {
        WalletKitRust.config = WalletKitRust.Config(
            projectId: projectId,
            groupIdentifier: groupIdentifier,
            metadata: metadata
        )
    }
}
