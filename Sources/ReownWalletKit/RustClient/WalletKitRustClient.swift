import Combine
import Foundation
import YttriumWrapper
import WalletConnectKMS
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
    
    init(yttriumClient: YttriumWrapper.SignClient) {
        self.yttriumClient = yttriumClient
        let projectIdKey = AgreementPrivateKey().rawRepresentation
        self.sessionStore = SessionStoreImpl()
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
    static func create(config: WalletKitRust.Config) -> WalletKitRustClient {
        let yttriumClient = YttriumWrapper.SignClient(
            projectId: config.projectId
        )
        
        return WalletKitRustClient(yttriumClient: yttriumClient)
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
        return WalletKitRustClientFactory.create(config: config)
    }()
    
    private static var config: Config?
    
    struct Config {
        let projectId: String
    }
    
    private init() { }
    
    /// WalletKitRust instance configuration method.
    /// - Parameters:
    ///   - relayUrl: The relay URL for the connection
    ///   - projectId: The project ID for the wallet connect
    ///   - clientId: The client ID for identification
    static public func configure(
        projectId: String
    ) {
        WalletKitRust.config = WalletKitRust.Config(
            projectId: projectId
        )
    }
}

extension Yttrium.SessionFfi {
    // we need to convert to codable type
    func toWCSession() -> CodableSession {
        
    }
}

class SessionStoreImpl: SessionStore {
    
    func addSession(session: Yttrium.SessionFfi) {
        // convert CodableSession and store in userdefaults
    }
    
    func deleteSession(topic: String) {
        //delete from userdefaults
    }
    
    func getSession(topic: String) -> Yttrium.SessionFfi? {
        //get codable session from userdefaults and return Yttrium.SessionFfi
    }
    
    func getAllSessions() -> [Yttrium.SessionFfi] {
        //get codable sessions from userdefaults and return [Yttrium.SessionFfi]

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
    var transportType: WalletConnectSign.TransportType
    var verifyContext: VerifyContext? //WalletConnectVerify.VerifyContext

    private(set) var acknowledged: Bool
    private(set) var expiryDate: Date
    private(set) var timestamp: Date
    private(set) var namespaces: [String: SessionNamespace]
    private(set) var requiredNamespaces: [String: ProposalNamespace]
    private(set) var sessionProperties: [String: String]?
    private(set) var scopedProperties: [String: String]?
}
