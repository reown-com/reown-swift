import Combine
import Foundation
import YttriumWrapper
import WalletConnectKMS
import WalletConnectUtils
import WalletConnectPairing
import WalletConnectVerify

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
/// WalletKitRust Client
///
/// Cannot be instantiated outside of the SDK
///
/// Access via `WalletKitRust.instance`
public class WalletKitRustClient {
    public enum Errors: Error {
        case failedToDecodeSessionProposal
    }
    
    // MARK: - Public Properties
    
    /// Publisher that sends session proposal
    ///
    /// event is emited on responder client only
    public var sessionProposalPublisher: AnyPublisher<(proposal: Session.Proposal, context: VerifyContext?), Never> {
        sessionProposalPublisherSubject.eraseToAnyPublisher()
    }
    
    public var sessionRequestPublisher: AnyPublisher<(request: Request, context: VerifyContext?), Never> {
        sessionRequestPublisherSubject.eraseToAnyPublisher()
    }
    private var sessionRequestPublisherSubject = PassthroughSubject<(request: Request, context: VerifyContext?), Never>()
    
    public var sessionsPublisher: AnyPublisher<[Session], Never> {
        sessionsPublisherSubject.eraseToAnyPublisher()
    }
    private let sessionsPublisherSubject = PassthroughSubject<[Session], Never>()


    private let sessionStore: SessionStoreImpl
    
    // MARK: - Private Properties
    private let yttriumClient: YttriumWrapper.SignClient
    private let sessionProposalPublisherSubject = PassthroughSubject<(proposal: Session.Proposal, context: VerifyContext?), Never>()
    private let appStateObserver = WalletKitAppStateObserver()
    
    init(yttriumClient: YttriumWrapper.SignClient,
         sessionStore: SessionStoreImpl) {
        self.yttriumClient = yttriumClient
        self.sessionStore = sessionStore
        let projectIdKey = AgreementPrivateKey().rawRepresentation

        
        // Set up sessions publisher callback
        sessionStore.onSessionsUpdate = { [weak self] in
            guard let self = self else { return }
            let sessions = self.getSessions()
            self.sessionsPublisherSubject.send(sessions)
        }
        
        // Set up app state observer to call online when entering foreground
        appStateObserver.onWillEnterForeground = { [weak self] in
            Task {
                await self?.yttriumClient.online()
            }
        }
        
        Task {
            await yttriumClient.registerSignListener(listener: self)
            await yttriumClient.start()
            registerLogger(logger: self)
            
            // Emit initial sessions after setup
            let sessions = getSessions()
            sessionsPublisherSubject.send(sessions)
        }
    }
    
    /// For wallet to receive a session proposal from a dApp
    /// Responder should call this function in order to accept peer's pairing and be able to subscribe for future session proposals.
    public func pair(uri: String) async throws -> Session.Proposal {
        let ffiProposal = try await yttriumClient.pair(uri: uri)
        guard let sessionProposal = ffiProposal.toSessionProposal() else {
            throw Errors.failedToDecodeSessionProposal
        }
        sessionProposalPublisherSubject.send((proposal: sessionProposal, context: nil))
        return sessionProposal
    }
    
    public func approve(_ proposal: Session.Proposal, approvedNamespaces: [String : SettleNamespace], selfMetadata: AppMetadata) async throws -> SessionFfi {
        // Convert Session.Proposal back to SessionProposalFfi for the Rust client
        guard let ffiProposal = proposal.toSessionProposalFfi() else {
            throw Errors.failedToDecodeSessionProposal
        }
        let yttriumMetadata = fromAppMetadata(selfMetadata)
        let sessionFfi = try await yttriumClient.approve(proposal: ffiProposal, approvedNamespaces: approvedNamespaces, selfMetadata: yttriumMetadata)
        
        // Trigger sessions update after successful approval
        let sessions = getSessions()
        sessionsPublisherSubject.send(sessions)
        
        return sessionFfi
    }
    
    public func getSessions() -> [Session] {
        sessionStore.getAllSessions().compactMap {$0.toCodableSession()?.publicRepresentation()}
    }
    
    /// Respond to a pending session request via Yttrium
    public func respond(topic: String, requestId: RPCID, response: RPCResult) async throws {
        let ffiResponse = try response.toYttriumFfiResponse(id: requestId)
        
        try await yttriumClient.respond(topic: topic, response: ffiResponse)
    }
    
    /// For the wallet to reject a session proposal
    /// - Parameters:
    ///   - proposal: Session Proposal to reject
    public func reject(_ proposal: Session.Proposal, reason: RejectionReason) async throws {
//         Convert Session.Proposal back to SessionProposalFfi for the Rust client
        guard let ffiProposal = proposal.toSessionProposalFfi() else {
            throw Errors.failedToDecodeSessionProposal
        }
        
        try await yttriumClient.reject(proposal: proposal.toSessionProposalFfi()!, reason: reason.ffi)
    }
    
    public func update(topic: String, namespaces: [String: SettleNamespace]) async throws {
        try await yttriumClient.update(topic: topic, namespaces: namespaces)
    }
    
    /// Manually trigger sessions update
    /// This will emit the current sessions through the sessionsPublisher
    public func refreshSessions() {
        let sessions = getSessions()
        sessionsPublisherSubject.send(sessions)
    }

    /// For a wallet and a dApp to terminate a session
    ///
    /// Should Error:
    /// - When the session topic is not found
    /// - Parameters:
    ///   - topic: Session topic that you want to delete
    public func disconnect(topic: String) async throws {
        sessionStore.deleteSession(topic: topic)
        // Trigger sessions update after successful disconnection
        let sessions = getSessions()
        sessionsPublisherSubject.send(sessions)
    }
}

struct WalletKitRustClientFactory {
    static func create(
        config: WalletKitRust.Config,
        groupIdentifier: String
    ) -> WalletKitRustClient {
        let keychainStorage = KeychainStorage(serviceIdentifier: "com.walletconnect.sdk", accessGroup: groupIdentifier)

        let kms = KeyManagementService(keychain: keychainStorage)
        
        // to do store the project id key in keychain and retrieve it for migration
        let projectIdKey = AgreementPrivateKey().rawRepresentation
        
        let sessionStore = SessionStoreImpl(kms: kms)

        
        let yttriumClient = YttriumWrapper.SignClient(
            projectId: config.projectId,
            key: projectIdKey,
            sessionStore: sessionStore
        )
        
        return WalletKitRustClient(yttriumClient: yttriumClient, sessionStore: sessionStore)
    }
}

extension WalletKitRustClient: SignListener, Logger {
    public func onSessionRequestResponse(id: UInt64, topic: String, response: Yttrium.SessionRequestJsonRpcResponseFfi) {
        //todo
    }
    
    public func onSessionUpdate(id: UInt64, topic: String, namespaces: [String : Yttrium.SettleNamespace]) {
        //todo
    }
    
    public func onSessionDisconnect(id: UInt64, topic: String) {
        //todo
    }
    
    public func onSessionEvent(id: UInt64, topic: String, params: Bool) {
        //todo
    }
    
    public func onSessionExtend(id: UInt64, topic: String) {
        //todo
    }
    
    public func onSessionConnect(id: UInt64) {
        //todo
    }
    
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


public enum RejectionReason {
    case userRejected
    case unsupportedChains
    case unsupportedMethods
    case unsupportedAccounts
    case unsupportedEvents
    
    var ffi: YttriumWrapper.RejectionReason {
        switch self {
        case .userRejected:
            YttriumWrapper.RejectionReason.userRejected
        case .unsupportedChains:
            YttriumWrapper.RejectionReason.unsupportedChains
        case .unsupportedMethods:
            YttriumWrapper.RejectionReason.unsupportedMethods
        case .unsupportedAccounts:
            YttriumWrapper.RejectionReason.unsupportedAccounts
        case .unsupportedEvents:
            YttriumWrapper.RejectionReason.unsupportedEvents
        }
    }
}





// MARK: - App State Observer
class WalletKitAppStateObserver {
    @objc var onWillEnterForeground: (() -> Void)?
    @objc var onWillEnterBackground: (() -> Void)?

    init() {
        subscribeNotificationCenter()
    }

    private func subscribeNotificationCenter() {
#if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil)
#elseif os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: NSApplication.willBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: NSApplication.willResignActiveNotification,
            object: nil)
#endif
    }

    @objc
    private func appWillEnterBackground() {
        onWillEnterBackground?()
    }

    @objc
    private func appWillEnterForeground() {
        onWillEnterForeground?()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - SessionProposal Conversion
extension SessionProposalFfi {
    func toSessionProposal() -> Session.Proposal? {
        // Convert Yttrium.Metadata to AppMetadata
        guard let appMetadata = toAppMetadata(metadata) else {
            return nil
        }
        
        // Convert required namespaces from Yttrium.ProposalNamespace to WalletConnectSign.ProposalNamespace
        let wcRequiredNamespaces: [String: ProposalNamespace] = requiredNamespaces.mapValues { ffiNs in
            let chains = ffiNs.chains.compactMap { Blockchain($0) }
            return ProposalNamespace(
                chains: chains.isEmpty ? nil : chains,
                methods: Set(ffiNs.methods),
                events: Set(ffiNs.events)
            )
        }
        
        // Convert optional namespaces
        let wcOptionalNamespaces: [String: ProposalNamespace]? = optionalNamespaces?.mapValues { ffiNs in
            let chains = ffiNs.chains.compactMap { Blockchain($0) }
            return ProposalNamespace(
                chains: chains.isEmpty ? nil : chains,
                methods: Set(ffiNs.methods),
                events: Set(ffiNs.events)
            )
        }

        // Convert Yttrium.Relay to RelayProtocolOptions
        let wcRelays = [RelayProtocolOptions(protocol: "irn", data: nil)]
        
        // Create SessionProposal for the internal proposal field
        let proposer = Participant(publicKey: proposerPublicKey.toHexString(), metadata: appMetadata)
            
        let sessionProposal = SessionProposal(
            relays: wcRelays,
            proposer: proposer,
            requiredNamespaces: wcRequiredNamespaces,
            optionalNamespaces: wcOptionalNamespaces,
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties
        )
        
        return Session.Proposal(
            id: id,
            pairingTopic: topic,
            pairingSymKey: pairingSymKey,
            proposer: appMetadata,
            requiredNamespaces: wcRequiredNamespaces,
            optionalNamespaces: wcOptionalNamespaces,
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties,
            proposal: sessionProposal
        )
    }
}

// MARK: - Session.Proposal back to SessionProposalFfi Conversion
extension Session.Proposal {
    func toSessionProposalFfi() -> SessionProposalFfi? {
        // Convert AppMetadata back to Yttrium.Metadata
        let yttriumMetadata = fromAppMetadata(proposer)
        
        // Get proposer public key from internal proposal
        let proposerPublicKey = Data(hex: proposal.proposer.publicKey)
        
        // Convert RelayProtocolOptions back to Yttrium.Relay
        let yttriumRelays = proposal.relays.map { relay in
            Yttrium.Relay(protocol: relay.protocol)
        }
        
        // Convert required namespaces from WalletConnectSign.ProposalNamespace to Yttrium.ProposalNamespace
        let yttriumRequiredNamespaces: [String: Yttrium.ProposalNamespace] = requiredNamespaces.mapValues { wcNs in
            let chains = (wcNs.chains ?? []).map { $0.absoluteString }
            return Yttrium.ProposalNamespace(
                chains: chains,
                methods: Array(wcNs.methods),
                events: Array(wcNs.events)
            )
        }
        
        // Convert optional namespaces
        let yttriumOptionalNamespaces: [String: Yttrium.ProposalNamespace]? = optionalNamespaces?.mapValues { wcNs in
            let chains = (wcNs.chains ?? []).map { $0.absoluteString }
            return Yttrium.ProposalNamespace(
                chains: chains,
                methods: Array(wcNs.methods),
                events: Array(wcNs.events)
            )
        }
        
        
        
        return SessionProposalFfi(
            id: id,
            topic: pairingTopic,
            pairingSymKey: pairingSymKey,
            proposerPublicKey: proposerPublicKey,
            relays: yttriumRelays,
            requiredNamespaces: yttriumRequiredNamespaces,
            optionalNamespaces: yttriumOptionalNamespaces,
            metadata: yttriumMetadata,
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties,
            expiryTimestamp: proposal.expiryTimestamp
        )
    }
}
