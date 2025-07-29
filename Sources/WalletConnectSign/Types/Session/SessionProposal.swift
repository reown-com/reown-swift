import Foundation

public struct ProposalRequests: Codable, Equatable {
    public let authentication: [AuthObject]
}

public struct ProposalRequestsResponses: Codable, Equatable {
    public let authentication: [AuthPayload]
}

struct SessionProposal: Codable, Equatable {
    
    let relays: [RelayProtocolOptions]
    let proposer: Participant
    let requiredNamespaces: [String: ProposalNamespace]
    let optionalNamespaces: [String: ProposalNamespace]?
    let sessionProperties: [String: String]?
    let scopedProperties: [String: String]?
    let expiryTimestamp: UInt64?
    let requests: ProposalRequests?

    static let proposalTtl: TimeInterval = 300 // 5 minutes

    internal init(relays: [RelayProtocolOptions],
                  proposer: Participant,
                  requiredNamespaces: [String : ProposalNamespace],
                  optionalNamespaces: [String : ProposalNamespace]? = nil,
                  sessionProperties: [String : String]? = nil,
                  scopedProperties: [String : String]? = nil,
                  requests: ProposalRequests? = nil) {
        self.relays = relays
        self.proposer = proposer
        self.requiredNamespaces = requiredNamespaces
        self.optionalNamespaces = optionalNamespaces
        self.sessionProperties = sessionProperties
        self.scopedProperties = scopedProperties
        self.expiryTimestamp = UInt64(Date().timeIntervalSince1970 + Self.proposalTtl)
        self.requests = requests
    }

    func publicRepresentation(pairingTopic: String) -> Session.Proposal {
        return Session.Proposal(
            id: proposer.publicKey,
            pairingTopic: pairingTopic,
            proposer: proposer.metadata,
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces ?? [:],
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties,
            proposal: self,
            requests: requests
        )
    }

    func isExpired(currentDate: Date = Date()) -> Bool {
        guard let expiry = expiryTimestamp else { return false }

        let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiry))

        return expiryDate < currentDate
    }
}
