import Foundation

/**
 A representation of an active session connection.
 */
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
    public static var defaultTimeToLive: Int64 {
        WCSession.defaultTimeToLive
    }
    
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
        public let proposer: AppMetadata
        public let requiredNamespaces: [String: ProposalNamespace]
        public let optionalNamespaces: [String: ProposalNamespace]?
        public let sessionProperties: [String: String]?

        // TODO: Refactor internal objects to manage only needed data
        internal let proposal: SessionProposal

        func isExpired() -> Bool {
            return proposal.isExpired()
        }

        init(
            id: String,
            pairingTopic: String,
            proposer: AppMetadata,
            requiredNamespaces: [String: ProposalNamespace],
            optionalNamespaces: [String: ProposalNamespace]?,
            sessionProperties: [String: String]?,
            proposal: SessionProposal
        ) {
            self.id = id
            self.pairingTopic = pairingTopic
            self.proposer = proposer
            self.requiredNamespaces = requiredNamespaces
            self.optionalNamespaces = optionalNamespaces
            self.sessionProperties = sessionProperties
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
        
        internal func internalRepresentation() -> SessionType.EventParams.Event {
            SessionType.EventParams.Event(name: name, data: data)
        }
    }

    public var accounts: [Account] {
        return namespaces.values.reduce(into: []) { result, namespace in
            result = result + Array(namespace.accounts)
        }
    }
}
