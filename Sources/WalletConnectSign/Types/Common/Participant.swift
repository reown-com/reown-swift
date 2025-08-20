import Foundation

public struct Participant: Codable, Equatable {
    let publicKey: String
    let metadata: AppMetadata

    public init(publicKey: String, metadata: AppMetadata) {
        self.publicKey = publicKey
        self.metadata = metadata
    }
}

public struct AgreementPeer: Codable, Equatable {
    public init(publicKey: String) {
        self.publicKey = publicKey
    }
    
    let publicKey: String
}
