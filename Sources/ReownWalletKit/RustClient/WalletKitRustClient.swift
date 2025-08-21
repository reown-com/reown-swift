import Combine
import Foundation
import YttriumWrapper
import WalletConnectKMS
import WalletConnectUtils
import WalletConnectPairing
import WalletConnectSign
/// WalletKitRust Client
///
/// Cannot be instantiated outside of the SDK
///
/// Access via `WalletKitRust.instance`
public class WalletKitRustClient {
    
    // MARK: - Public Properties
    
    /// Publisher that sends session proposal
    ///
    /// event is emited on responder client only
    public var sessionProposalPublisher: AnyPublisher<(proposal: SessionProposalFfi, context: VerifyContext?), Never> {
        sessionProposalPublisherSubject.eraseToAnyPublisher()
    }
    
    public var sessionRequestPublisher: AnyPublisher<(request: Request, context: VerifyContext?), Never> {
        sessionRequestPublisherSubject.eraseToAnyPublisher()
    }
    private var sessionRequestPublisherSubject = PassthroughSubject<(request: Request, context: VerifyContext?), Never>()

    private let sessionStore: SessionStore
    
    // MARK: - Private Properties
    private let yttriumClient: YttriumWrapper.SignClient
    private let sessionProposalPublisherSubject = PassthroughSubject<(proposal: SessionProposalFfi, context: VerifyContext?), Never>()
    
    init(yttriumClient: YttriumWrapper.SignClient,
         kms: KeyManagementServiceProtocol) {
        self.yttriumClient = yttriumClient

        let projectIdKey = AgreementPrivateKey().rawRepresentation
        self.sessionStore = SessionStoreImpl(kms: kms)
        Task {
            await yttriumClient.setKey(key: projectIdKey)
            await yttriumClient.registerSignListener(listener: self)
            await yttriumClient.registerSessionStore(sessionStore: sessionStore)
            registerLogger(logger: self)
        }
    }
    
    /// For wallet to receive a session proposal from a dApp
    /// Responder should call this function in order to accept peer's pairing and be able to subscribe for future session proposals.
    public func pair(uri: String) async throws -> SessionProposalFfi {
        let proposal = try await yttriumClient.pair(uri: uri)
        sessionProposalPublisherSubject.send((proposal: proposal, context: nil))
        return proposal
    }
    
    public func approve(_ proposal: SessionProposalFfi, approvedNamespaces: [String : SettleNamespace], selfMetadata: Metadata) async throws -> SessionFfi {
        return try await yttriumClient.approve(proposal: proposal, approvedNamespaces: approvedNamespaces, selfMetadata: selfMetadata)
    }
}

struct WalletKitRustClientFactory {
    static func create(
        config: WalletKitRust.Config,
        groupIdentifier: String
    ) -> WalletKitRustClient {
        let keychainStorage = KeychainStorage(serviceIdentifier: "com.walletconnect.sdk", accessGroup: groupIdentifier)

        let kms = KeyManagementService(keychain: keychainStorage)

        let yttriumClient = YttriumWrapper.SignClient(
            projectId: config.projectId
        )
        
        return WalletKitRustClient(yttriumClient: yttriumClient, kms: kms)
    }
}

extension WalletKitRustClient: SignListener, Logger {
    public func log(message: String) {
        print("RUST: \(message)")
    }
    
    public func onSessionRequest(topic: String, sessionRequest: Yttrium.SessionRequestJsonRpcFfi) {
        // Convert Yttrium.SessionRequestJsonRpcFfi to WalletConnect Request
        // Expecting chainId in CAIP-2 format (e.g., "eip155:1") and params as a JSON string
        guard let chainId = Blockchain(sessionRequest.params.chainId) else {
            return
        }

        let paramsJsonString = sessionRequest.params.request.params
        guard let paramsData = paramsJsonString.data(using: .utf8) else {
            return
        }

        do {
            let anyParams = try JSONDecoder().decode(AnyCodable.self, from: paramsData)

            let intId = Int64(exactly: sessionRequest.id)!
            let rpcId: RPCID = .right(intId)

            let method = sessionRequest.params.request.method
            let expiry = sessionRequest.params.request.expiry

            let request = Request(
                id: rpcId,
                topic: topic,
                method: method,
                params: anyParams,
                chainId: chainId,
                expiryTimestamp: expiry
            )

            self.sessionRequestPublisherSubject.send((request: request, context: nil))
        } catch {
            return
        }
    }
    
    public func onSessionRequestJson(topic: String, sessionRequest: String) {
        // we are ignoring this
    }
    
    
}


public class WalletKitRust {
    
    /// WalletKitRust client instance
    public static var instance: WalletKitRustClient = {
        guard let config = WalletKitRust.config else {
            fatalError("Error - you must call WalletKitRust.configure(_:) before accessing the shared instance.")
        }
        return WalletKitRustClientFactory.create(config: config, groupIdentifier: config.groupIdentifier)
    }()
    
    private static var config: Config?
    
    struct Config {
        let projectId: String
        let groupIdentifier: String
    }
    
    private init() { }
    
    /// WalletKitRust instance configuration method.
    /// - Parameters:
    ///   - projectId: The project ID for the wallet connect
    static public func configure(
        projectId: String,
        groupIdentifier: String
    ) {
        WalletKitRust.config = WalletKitRust.Config(
            projectId: projectId,
            groupIdentifier: groupIdentifier
        )
    }
}


class SessionStoreImpl: SessionStore {
    private let store: CodableStore<CodableSession>
    private let kms: KeyManagementServiceProtocol

    init(defaults: KeyValueStorage = UserDefaults.standard,
         kms: KeyManagementServiceProtocol) {
        self.store = CodableStore<CodableSession>(
            defaults: defaults,
            identifier: SignStorageIdentifiers.sessions.rawValue
        )
        self.kms = kms
    }

    func addSession(session: Yttrium.SessionFfi) {
        // Convert to CodableSession and store
        guard let codable = session.toCodableSession() else {
            print("SessionStore: Failed to convert SessionFfi to CodableSession")
            return
        }
        store.set(codable, forKey: codable.topic)
    }

    func deleteSession(topic: String) {
        store.delete(forKey: topic)
    }

    func getSession(topic: String) -> Yttrium.SessionFfi? {
        // Try decode as CodableSession (migration compatible with WCSession JSON layout)
        guard let codable = try? store.get(key: topic) else { return nil }
        
        let symKey =  kms.getSymmetricKey(for: topic)!.rawRepresentation
        
        return codable.toYttriumSession(symKey: symKey)
    }

    func getAllSessions() -> [Yttrium.SessionFfi] {
        let all = store.getAll()
        fatalError("to be implemented")
//        return all.compactMap { $0.toYttriumSession() }
    }
}

struct CodableSession: Codable {
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
        let namespaces: [String: CodableSession.SessionNamespace] = sessionNamespaces.reduce(into: [:]) { acc, element in
            let (key, ffiNs) = element
            let accounts: [Account] = ffiNs.accounts.compactMap { Account($0) }
            let chains: [Blockchain]? = {
                let chainStrings = ffiNs.chains
                if chainStrings.isEmpty { return nil }
                return chainStrings.compactMap { Blockchain($0) }
            }()
            let methods = Set(ffiNs.methods)
            let events = Set(ffiNs.events)
            acc[key] = CodableSession.SessionNamespace(chains: chains, accounts: accounts, methods: methods, events: events)
        }

        let requiredNamespaces: [String: CodableSession.ProposalNamespace] = self.requiredNamespaces.mapValues { ffiNs in
            let chains = ffiNs.chains.compactMap { Blockchain($0) }
            return CodableSession.ProposalNamespace(chains: chains, methods: Set(ffiNs.methods), events: Set(ffiNs.events))
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
