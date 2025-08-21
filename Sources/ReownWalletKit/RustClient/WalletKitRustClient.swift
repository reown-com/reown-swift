import Combine
import Foundation
import YttriumWrapper
import WalletConnectKMS
import WalletConnectUtils
import WalletConnectPairing
import WalletConnectSign

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
    private let appStateObserver = WalletKitAppStateObserver()
    
    init(yttriumClient: YttriumWrapper.SignClient,
         kms: KeyManagementServiceProtocol) {
        self.yttriumClient = yttriumClient

        let projectIdKey = AgreementPrivateKey().rawRepresentation
        self.sessionStore = SessionStoreImpl(kms: kms)
        
        // Set up app state observer to call online when entering foreground
        appStateObserver.onWillEnterForeground = { [weak self] in
            Task {
                await self?.yttriumClient.online()
            }
        }
        
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
        return all.compactMap { session in
            guard let symKey = kms.getSymmetricKey(for: session.topic) else {
                print("SessionStore: Failed to get symmetric key for topic: \(session.topic)")
                return nil
            }
            return session.toYttriumSession(symKey: symKey.rawRepresentation)
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
