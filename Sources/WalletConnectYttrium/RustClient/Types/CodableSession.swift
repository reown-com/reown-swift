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
import WalletConnectVerify


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
    let sessionSymKey: Data
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


extension CodableSession {
    // Convert persisted Codable session back to FFI for the rust client
    func toYttriumSession() -> Yttrium.SessionFfi? {
        // Metadata
        
        let selfMeta = fromAppMetadata(selfParticipant.metadata)
        let peerMeta = fromAppMetadata(peerParticipant.metadata)
        

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
            sessionSymKey: self.sessionSymKey,
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
func toAppMetadata(_ m: Yttrium.Metadata) -> AppMetadata? {
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

func fromAppMetadata(_ m: AppMetadata) -> Yttrium.Metadata {
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
