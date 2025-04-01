import Foundation

/// Protocol for wallet service request handling
protocol WalletServiceSessionRequestable {
    /// Makes an HTTP request to the wallet service
    func request(_ request: Request, to url: URL) async throws -> AnyCodable
}

extension WalletServiceSessionRequester: WalletServiceSessionRequestable {} 