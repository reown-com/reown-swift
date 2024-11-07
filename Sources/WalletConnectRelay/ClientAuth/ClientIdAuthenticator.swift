import Foundation

public protocol ClientIdAuthenticating {
    func createAuthToken(url: String) throws -> String
    func refreshTokenIfNeeded(token: String, url: String) throws -> String 
}

public final class ClientIdAuthenticator: ClientIdAuthenticating {
    private let clientIdStorage: ClientIdStoring

    public init(clientIdStorage: ClientIdStoring) {
        self.clientIdStorage = clientIdStorage
    }

    public func createAuthToken(url: String) throws -> String {
        let keyPair = try clientIdStorage.getOrCreateKeyPair()
        let payload = RelayAuthPayload(subject: getSubject(), audience: url)
        return try payload.signAndCreateWrapper(keyPair: keyPair).jwtString
    }

    public func refreshTokenIfNeeded(token: String, url: String) throws -> String {
        if try isTokenExpired(token: token) {
            // Token has expired, generate a new one
            return try createAuthToken(url: url)
        } else {
            // Token is still valid, return existing token
            return token
        }
    }

    private func isTokenExpired(token: String) throws -> Bool {
        // Use the JWT classes to decode and verify the token
        let wrapper = RelayAuthPayload.Wrapper(jwtString: token)
        let (_, claims) = try RelayAuthPayload.decodeAndVerify(from: wrapper)

        let expiryTime = TimeInterval(claims.exp)
        let currentTime = Date().timeIntervalSince1970

        // Check if the token will be valid for at least the next 50 seconds
        // If the token expires within the next 60 seconds, consider it expired
        return (expiryTime - currentTime) <= 60
    }

    private func getSubject() -> String {
        return Data.randomBytes(count: 32).toHexString()
    }
}
