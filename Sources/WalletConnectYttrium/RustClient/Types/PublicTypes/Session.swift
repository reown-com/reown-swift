//
//  Session.swift
//  reown
//
//  Created by BARTOSZ ROZWARSKI on 29/08/2025.
//


/**
 A representation of an active session connection.
 */
import Foundation

public struct Session: Codable {
    public let topic: String
    @available(*, deprecated, message: "The pairingTopic property is deprecated.")
    public let pairingTopic: String
    public let peer: AppMetadata
    public let requiredNamespaces: [String: ProposalNamespace]
    public let namespaces: [String: SessionNamespace]
    public let sessionProperties: [String: String]?
    public let scopedProperties: [String: String]?
    public let expiryDate: Date
    
    public init(
        topic: String,
        pairingTopic: String,
        peer: AppMetadata,
        requiredNamespaces: [String: ProposalNamespace],
        namespaces: [String: SessionNamespace],
        sessionProperties: [String: String]?,
        scopedProperties: [String: String]?,
        expiryDate: Date
    ) {
        self.topic = topic
        self.pairingTopic = pairingTopic
        self.peer = peer
        self.requiredNamespaces = requiredNamespaces
        self.namespaces = namespaces
        self.sessionProperties = sessionProperties
        self.scopedProperties = scopedProperties
        self.expiryDate = expiryDate
    }
}

extension Session {

    public struct Proposal: Equatable, Codable {
        public var id: String
        public let pairingTopic: String
        public let pairingSymKey: Data
        public let proposer: AppMetadata
        public let requiredNamespaces: [String: ProposalNamespace]
        public let optionalNamespaces: [String: ProposalNamespace]?
        public let sessionProperties: [String: String]?
        public let scopedProperties: [String: String]?

        // TODO: Refactor internal objects to manage only needed data
        internal let proposal: SessionProposal

        func isExpired() -> Bool {
            return proposal.isExpired()
        }

        init(
            id: String,
            pairingTopic: String,
            pairingSymKey: Data,
            proposer: AppMetadata,
            requiredNamespaces: [String: ProposalNamespace],
            optionalNamespaces: [String: ProposalNamespace]?,
            sessionProperties: [String: String]?,
            scopedProperties: [String: String]?,
            proposal: SessionProposal
        ) {
            self.id = id
            self.pairingTopic = pairingTopic
            self.pairingSymKey = pairingSymKey
            self.proposer = proposer
            self.requiredNamespaces = requiredNamespaces
            self.optionalNamespaces = optionalNamespaces
            self.sessionProperties = sessionProperties
            self.scopedProperties = scopedProperties
            self.proposal = proposal
        }
    }

    public struct Event: Equatable, Hashable {
        public let name: String
        public let data: AnyCodable

        public init(name: String, data: AnyCodable) {
            self.name = name
            self.data = data
        }
        
    }

    public var accounts: [Account] {
        return namespaces.values.reduce(into: []) { result, namespace in
            result = result + Array(namespace.accounts)
        }
    }
}



struct SessionProposal: Codable, Equatable {
    
    let relays: [RelayProtocolOptions]
    let proposer: Participant
    let requiredNamespaces: [String: ProposalNamespace]
    let optionalNamespaces: [String: ProposalNamespace]?
    let sessionProperties: [String: String]?
    let scopedProperties: [String: String]?
    let expiryTimestamp: UInt64?

    static let proposalTtl: TimeInterval = 300 // 5 minutes

    internal init(relays: [RelayProtocolOptions],
                  proposer: Participant,
                  requiredNamespaces: [String : ProposalNamespace],
                  optionalNamespaces: [String : ProposalNamespace]? = nil,
                  sessionProperties: [String : String]? = nil,
                  scopedProperties: [String : String]? = nil) {
        self.relays = relays
        self.proposer = proposer
        self.requiredNamespaces = requiredNamespaces
        self.optionalNamespaces = optionalNamespaces
        self.sessionProperties = sessionProperties
        self.scopedProperties = scopedProperties
        self.expiryTimestamp = UInt64(Date().timeIntervalSince1970 + Self.proposalTtl)
    }

    func isExpired(currentDate: Date = Date()) -> Bool {
        guard let expiry = expiryTimestamp else { return false }

        let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiry))

        return expiryDate < currentDate
    }
}
