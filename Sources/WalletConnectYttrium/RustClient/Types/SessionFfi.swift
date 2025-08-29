//
//  SessionFfi.swift
//  reown
//
//  Created by BARTOSZ ROZWARSKI on 29/08/2025.
//

import Foundation


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
            sessionSymKey: sessionSymKey,
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
