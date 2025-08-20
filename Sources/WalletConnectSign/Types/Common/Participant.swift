import Foundation

public struct Participant: Codable, Equatable {
    let publicKey: String
    let metadata: AppMetadata

    init(publicKey: String, metadata: AppMetadata) {
        self.publicKey = publicKey
        self.metadata = metadata
    }
}

public struct AgreementPeer: Codable, Equatable {
    let publicKey: String
}
