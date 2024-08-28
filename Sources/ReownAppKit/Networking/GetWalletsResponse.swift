import Foundation

struct GetWalletsResponse: Codable {
    let count: Int
    let data: [Wallet]
}

struct GetIosDataResponse: Codable {
    let count: Int
    let data: [WalletMetadata]
    
    struct WalletMetadata: Codable {
        let id: String
        let ios_schema: String
    }
}
