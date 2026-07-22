import Foundation

/// Builds the WalletConnect Pay checkout URL to load inside the WebView.
///
/// Mirrors the React Native reference implementation: start from the `gatewayUrl`
/// returned by the Merchant API and append the two required WebView parameters —
/// never construct the base URL manually.
enum PayURLBuilder {
    /// The DApp sample's registered native deep link scheme (see `Info.plist` /
    /// `AppMetadata.Redirect(native:)` in `SceneDelegate`). Wallets return here after signing.
    static let defaultReturnURL = "wcdapp://"

    enum BuildError: LocalizedError {
        case notHTTPS
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .notHTTPS:
                return "The payment URL must be a secure https:// URL."
            case .invalidURL:
                return "The payment URL is not valid."
            }
        }
    }

    /// Appends `returnUrl` and `preferUniversalLinks=1` to the gateway URL.
    /// Rejects any non-`https` input to avoid loading arbitrary schemes.
    static func buildPayURL(gatewayUrl: String, returnUrl: String = defaultReturnURL) throws -> URL {
        let trimmed = gatewayUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var components = URLComponents(string: trimmed) else {
            throw BuildError.invalidURL
        }
        guard components.scheme?.lowercased() == "https" else {
            throw BuildError.notHTTPS
        }

        var queryItems = components.queryItems ?? []
        // Required: the wallet returns here after signing.
        queryItems.append(URLQueryItem(name: "returnUrl", value: returnUrl))
        // Required: open wallets via universal links instead of custom schemes.
        queryItems.append(URLQueryItem(name: "preferUniversalLinks", value: "1"))
        components.queryItems = queryItems

        guard let url = components.url else {
            throw BuildError.invalidURL
        }
        return url
    }
}
