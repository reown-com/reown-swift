import Combine
import YttriumWrapper

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
    
    // MARK: - Private Properties
    private let yttriumClient: YttriumWrapper.SignClient
    private let sessionProposalPublisherSubject = PassthroughSubject<(proposal: SessionProposalFfi, context: VerifyContext?), Never>()
    
    init(yttriumClient: YttriumWrapper.SignClient) {
        self.yttriumClient = yttriumClient
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
