import Foundation

public struct MessageVerifierFactory {

    public let crypto: CryptoProvider

    public init(crypto: CryptoProvider) {
        self.crypto = crypto
    }

    public func create() -> MessageVerifier {
        return create(projectId: Networking.projectId)
    }

    public func create(projectId: String) -> MessageVerifier {

        return MessageVerifier(crypto: crypto, projectId: projectId)
    }
}
