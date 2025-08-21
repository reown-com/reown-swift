//
//  File.swift
//  reown
//
//  Created by BARTOSZ ROZWARSKI on 21/08/2025.
//

import Foundation
import YttriumWrapper
import WalletConnectKMS
import WalletConnectUtils
import WalletConnectPairing
import WalletConnectSign

public struct ProposalNamespace: Equatable, Codable {
    public let chains: [Blockchain]?
    public let methods: Set<String>
    public let events: Set<String>
    
    public init(chains: [Blockchain]? = nil, methods: Set<String>, events: Set<String>) {
        self.chains = chains
        self.methods = methods
        self.events = events
    }
}

public struct SessionNamespace: Equatable, Codable {
    public var chains: [Blockchain]?
    public var accounts: [Account]
    public var methods: Set<String>
    public var events: Set<String>
    
    public init(chains: [Blockchain]? = nil, accounts: [Account], methods: Set<String>, events: Set<String>) {
        self.chains = chains
        self.accounts = accounts
        self.methods = methods
        self.events = events
    }
}
struct CodableSession: Codable {
    
    let topic: String
    let pairingTopic: String
    let relay: RelayProtocolOptions
    let selfParticipant: Participant
    let peerParticipant: Participant
    let controller: AgreementPeer
    var transportType: TransportType
    var verifyContext: VerifyContext? //WalletConnectVerify.VerifyContext

    private(set) var acknowledged: Bool
    private(set) var expiryDate: Date
    private(set) var timestamp: Date
    private(set) var namespaces: [String: SessionNamespace]
    private(set) var requiredNamespaces: [String: ProposalNamespace]
    private(set) var sessionProperties: [String: String]?
    private(set) var scopedProperties: [String: String]?
    
    func publicRepresentation() -> Session {
        return Session(
            topic: topic,
            pairingTopic: pairingTopic,
            peer: peerParticipant.metadata,
            requiredNamespaces: requiredNamespaces,
            namespaces: namespaces,
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties,
            expiryDate: expiryDate
        )
    }
}

// MARK: - Migration-compatible CodingKeys
extension CodableSession {
    enum CodingKeys: String, CodingKey {
        case topic, pairingTopic, relay, selfParticipant, peerParticipant, controller, transportType, verifyContext, acknowledged, expiryDate, timestamp, namespaces, requiredNamespaces, sessionProperties, scopedProperties
    }
}

// MARK: - Conversions between FFI and Codable
extension Yttrium.SessionFfi {
    // Convert FFI session to Swift Codable mirror of WCSession for persistence
    func toCodableSession() -> CodableSession? {
        // Participants
        guard
            let peerPublicKey = peerPublicKey?.toHexString(),
            let peerMetaData = peerMetaData,
            let controllerKeyHex = controllerKey?.toHexString()
        else {
            return nil
        }

        guard let selfAppMetadata = toAppMetadata(selfMetaData), let peerAppMetadata = toAppMetadata(peerMetaData) else {
            return nil
        }

        let selfParticipant = Participant(publicKey: selfPublicKey.toHexString(), metadata: selfAppMetadata)
        let peerParticipant = Participant(publicKey: peerPublicKey, metadata: peerAppMetadata)
        let controller = AgreementPeer(publicKey: controllerKeyHex)

        // Relay
        let relay = RelayProtocolOptions(protocol: relayProtocol, data: relayData)

        // Namespaces
        let namespaces: [String: SessionNamespace] = sessionNamespaces.reduce(into: [:]) { acc, element in
            let (key, ffiNs) = element
            let accounts: [Account] = ffiNs.accounts.compactMap { Account($0) }
            let chains: [Blockchain]? = {
                let chainStrings = ffiNs.chains
                if chainStrings.isEmpty { return nil }
                return chainStrings.compactMap { Blockchain($0) }
            }()
            let methods = Set(ffiNs.methods)
            let events = Set(ffiNs.events)
            acc[key] = SessionNamespace(chains: chains, accounts: accounts, methods: methods, events: events)
        }

        let requiredNamespaces: [String: ProposalNamespace] = self.requiredNamespaces.mapValues { ffiNs in
            let chains = ffiNs.chains.compactMap { Blockchain($0) }
            return ProposalNamespace(chains: chains, methods: Set(ffiNs.methods), events: Set(ffiNs.events))
        }

        // Timing
        let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiry))
        let timestamp = Date()

        // Transport type (default to relay when unknown)
        let transportType: TransportType = {
            let t = self.transportType
            let desc = String(describing: t).lowercased()
            return desc.contains("link") ? .linkMode : .relay
        }()

        // Topic string best-effort
        let topicString = String(describing: topic)

        return CodableSession(
            topic: topicString,
            pairingTopic: pairingTopic,
            relay: relay,
            selfParticipant: selfParticipant,
            peerParticipant: peerParticipant,
            controller: controller,
            transportType: transportType,
            verifyContext: nil,
            acknowledged: isAcknowledged,
            expiryDate: expiryDate,
            timestamp: timestamp,
            namespaces: namespaces,
            requiredNamespaces: requiredNamespaces,
            sessionProperties: properties,
            scopedProperties: scopedProperties
        )
    }
}

extension CodableSession {
    // Convert persisted Codable session back to FFI for the rust client
    func toYttriumSession(symKey: Data) -> Yttrium.SessionFfi? {
        // Metadata
        guard
            let selfMeta = fromAppMetadata(selfParticipant.metadata),
            let peerMeta = fromAppMetadata(peerParticipant.metadata)
        else { return nil }

        // Keys
        let selfPubKey = Data(hex: selfParticipant.publicKey)
        let peerPubKey = Data(hex: peerParticipant.publicKey)
        let controllerKeyData = Data(hex: controller.publicKey)

        // Relay
        let relayProtocol = relay.protocol
        let relayData = relay.data

        // Namespaces
        let ffiNamespaces: [String: SettleNamespace] = namespaces.reduce(into: [:]) { acc, element in
            let (key, ns) = element
            let accounts = ns.accounts.map { $0.absoluteString }
            let chains = (ns.chains ?? []).map { $0.absoluteString }
            let methods = Array(ns.methods)
            let events = Array(ns.events)
            acc[key] = SettleNamespace(accounts: accounts, methods: methods, events: events, chains: chains)
        }

        let ffiRequiredNamespaces: [String: Yttrium.ProposalNamespace] = requiredNamespaces.reduce(into: [:]) { acc, element in
            let (key, ns) = element
            let chains = (ns.chains ?? []).map { $0.absoluteString }
            acc[key] = Yttrium.ProposalNamespace(chains: chains, methods: Array(ns.methods), events: Array(ns.events))
        }

        let optionalNamespaces: [String: Yttrium.ProposalNamespace]? = nil

        // Expiry seconds
        let expiry = UInt64(expiryDate.timeIntervalSince1970)

        // Convert transport type
        let yttriumTransportType: Yttrium.TransportType = {
            switch transportType {
            case .relay:
                return .relay
            case .linkMode:
                return .linkMode
            }
        }()


        let session = Yttrium.SessionFfi(
            requestId: 0,
            sessionSymKey: symKey,
            selfPublicKey: selfPubKey,
            topic: topic,
            expiry: expiry,
            relayProtocol: relayProtocol,
            relayData: relayData,
            controllerKey: controllerKeyData,
            selfMetaData: selfMeta,
            peerPublicKey: peerPubKey,
            peerMetaData: peerMeta,
            sessionNamespaces: ffiNamespaces,
            requiredNamespaces: ffiRequiredNamespaces,
            optionalNamespaces: optionalNamespaces,
            properties: sessionProperties,
            scopedProperties: scopedProperties,
            isAcknowledged: acknowledged,
            pairingTopic: pairingTopic,
            transportType: yttriumTransportType)
        return session
    }
}

// MARK: - Helpers
private func toAppMetadata(_ m: Yttrium.Metadata) -> AppMetadata? {
    guard let redirect = m.redirect else {
        return try? AppMetadata(
            name: m.name,
            description: m.description,
            url: m.url,
            icons: m.icons,
            redirect: .init(native: "", universal: nil)
        )
    }
    guard let appRedirect = try? AppMetadata.Redirect(native: redirect.native ?? "", universal: redirect.universal, linkMode: redirect.linkMode) else {
        return nil
    }
    return AppMetadata(name: m.name, description: m.description, url: m.url, icons: m.icons, redirect: appRedirect)
}

private func fromAppMetadata(_ m: AppMetadata) -> Yttrium.Metadata? {
    let redirect: Yttrium.Redirect?
    if let r = m.redirect {
        redirect = Yttrium.Redirect(native: r.native, universal: r.universal, linkMode: r.linkMode ?? false)
    } else {
        redirect = nil
    }
    return Yttrium.Metadata(name: m.name, description: m.description, url: m.url, icons: m.icons, verifyUrl: nil, redirect: redirect)
}



// WalletConnectSign types copies
public enum TransportType: String, Codable {
    case relay
    case linkMode
}

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

enum SignStorageIdentifiers: String {
    case pairings = "com.walletconnect.sdk.pairingSequences"
    case sessions = "com.walletconnect.sdk.sessionSequences"
    case proposals = "com.walletconnect.sdk.sessionProposals"
    case sessionTopicToProposal = "com.walletconnect.sdk.sessionTopicToProposal"
    case authResponseTopicRecord = "com.walletconnect.sdk.authResponseTopicRecord"
    case linkModeLinks = "com.walletconnect.sdk.linkModeLinks"
}

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
        public let scopedProperties: [String: String]?

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
            scopedProperties: [String: String]?,
            proposal: SessionProposal
        ) {
            self.id = id
            self.pairingTopic = pairingTopic
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

    func publicRepresentation(pairingTopic: String) -> Session.Proposal {
        return Session.Proposal(
            id: proposer.publicKey,
            pairingTopic: pairingTopic,
            proposer: proposer.metadata,
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces ?? [:],
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties,
            proposal: self
        )
    }

    func isExpired(currentDate: Date = Date()) -> Bool {
        guard let expiry = expiryTimestamp else { return false }

        let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiry))

        return expiryDate < currentDate
    }
}
