import class CoinbaseWalletSDK.CoinbaseWalletSDK
import struct CoinbaseWalletSDK.Action
import struct CoinbaseWalletSDK.ActionError
import Combine
import Foundation
import UIKit

// Web3 Modal Client
///
/// Cannot be instantiated outside of the SDK
///
/// Access via `Web3Modal.instance`
public class AppKitClient {
    // MARK: - Public Properties
    
    /// Publisher that sends sessions on every sessions update
    ///
    /// Event will be emited on controller and non-controller clients.
    public var sessionsPublisher: AnyPublisher<[Session], Never> {
        signClient.sessionsPublisher.eraseToAnyPublisher()
    }
    
    /// Publisher that sends session when one is settled
    ///
    /// Event is emited on proposer and responder client when both communicating peers have successfully established a session.
    public var sessionSettlePublisher: AnyPublisher<Session, Never> {
        signClient.sessionSettlePublisher.eraseToAnyPublisher()
    }
    
    /// Publisher that sends session proposal that has been rejected
    ///
    /// Event will be emited on dApp client only.
    public var sessionRejectionPublisher: AnyPublisher<(Session.Proposal, Reason), Never> {
        signClient.sessionRejectionPublisher.eraseToAnyPublisher()
    }
    
    /// Publisher that sends deleted session topic
    ///
    /// Event can be emited on any type of the client.
    public var sessionDeletePublisher: AnyPublisher<(String, Reason), Never> {
        signClient.sessionDeletePublisher.eraseToAnyPublisher()
    }
    
    /// Publisher that sends response for session request
    ///
    /// In most cases that event will be emited on dApp client.
    public var sessionResponsePublisher: AnyPublisher<W3MResponse, Never> {
        signClient.sessionResponsePublisher
            .map { response in
                W3MResponse(
                    id: response.id,
                    topic: response.topic,
                    chainId: response.chainId,
                    result: response.result
                )
            }
            .merge(with: coinbaseResponseSubject)
            .eraseToAnyPublisher()
    }
    
    public var coinbaseResponseSubject = PassthroughSubject<W3MResponse, Never>()
    public var coinbaseConnectedSubject = PassthroughSubject<Void, Never>()
    
    public var didSelectWalletSubject = PassthroughSubject<Wallet, Never>()

    /// Publisher that sends web socket connection status
    public var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> {
        signClient.socketConnectionStatusPublisher.eraseToAnyPublisher()
    }
    
    /// Publisher that sends session event
    ///
    /// Event will be emited on dApp client only
    public var sessionEventPublisher: AnyPublisher<(event: Session.Event, sessionTopic: String, chainId: Blockchain?), Never> {
        signClient.sessionEventPublisher.eraseToAnyPublisher()
    }

    public var authResponsePublisher: AnyPublisher<(id: RPCID, result: Result<(Session?, [Cacao]), AuthError>), Never> {
        signClient.authResponsePublisher
    }

    public var isAnalyticsEnabled: Bool {
        return analyticsService.isAnalyticsEnabled
    }

    public var SIWEAuthenticationPublisher: AnyPublisher<Result<(message: String, signature: String), SIWEAuthenticationError>, Never> {
        return SIWEAuthenticationPublisherSubject.eraseToAnyPublisher()
    }

    internal let SIWEAuthenticationPublisherSubject = PassthroughSubject<Result<(message: String, signature: String), SIWEAuthenticationError>, Never>()

    // MARK: - Private Properties

    private let signClient: SignClient
    private let pairingClient: PairingClientProtocol & PairingInteracting & PairingRegisterer
    private let store: Store
    private let analyticsService: AnalyticsService
    private var disposeBag = Set<AnyCancellable>()
    public let logger: ConsoleLogging

    init(
        logger: ConsoleLogging,
        signClient: SignClient,
        pairingClient: PairingClientProtocol & PairingInteracting & PairingRegisterer,
        store: Store,
        analyticsService: AnalyticsService
    ) {
        self.logger = logger
        self.signClient = signClient
        self.pairingClient = pairingClient
        self.store = store
        self.analyticsService = analyticsService
        setUpConnectionEvents()
        analyticsService.track(.MODAL_LOADED)
    }
    
    /// For creating new pairing
    public func createPairing() async throws -> WalletConnectURI {
        logger.debug("Creating new pairing")
        do {
            return try await pairingClient.create()
        } catch {
            AppKit.config.onError(error)
            throw error
        }
    }
    
    /// For proposing a session to a wallet.
    /// Function will propose a session on existing pairing or create new one if not specified
    /// Namespaces from Web3Modal.config will be used
    /// - Parameters:
    ///   - topic: pairing topic
    public func connect(walletUniversalLink: String?) async throws -> WalletConnectURI? {
        logger.debug("Connecting Application")
        do {
            if let authParams = AppKit.config.authRequestParams {
                return try await signClient.authenticate(authParams, walletUniversalLink: walletUniversalLink)
            } else {
                let pairingURI = try await signClient.connect(
                    requiredNamespaces: AppKit.config.sessionParams.requiredNamespaces,
                    optionalNamespaces: AppKit.config.sessionParams.optionalNamespaces,
                    sessionProperties: AppKit.config.sessionParams.sessionProperties
                )
                return pairingURI
            }
        } catch {
            AppKit.config.onError(error)
            throw error
        }
    }
    
    public func request(_ request: W3MJSONRPC) async throws {
        logger.debug("Requesting: \(request.rawValues.method)")
        switch store.connectedWith {
        case .wc:
            guard
                let session = store.session,
                let chain = getSelectedChain(),
                let blockchain = Blockchain(namespace: chain.chainNamespace, reference: chain.chainReference)
            else { return }
            
            if case let .personal_sign(address, message) = request {
                try await signClient.request(
                    params: .init(
                        topic: session.topic,
                        method: request.rawValues.method,
                        params: AnyCodable(any: [message, address]),
                        chainId: blockchain
                    )
                )
            } else if case let .eth_signTypedData_v4(address, typedDataJson) = request {
                try await signClient.request(
                    params: .init(
                        topic: session.topic,
                        method: request.rawValues.method,
                        params: AnyCodable(any: [address, typedDataJson]),
                        chainId: blockchain
                    )
                )
            } else {
                try await signClient.request(
                    params: .init(
                        topic: session.topic,
                        method: request.rawValues.method,
                        params: AnyCodable(any: request.rawValues.params),
                        chainId: blockchain
                    )
                )
            }
        case .cb:
                    
            guard let jsonRpc = request.toCbAction() else { return }
                    
            // Execute on main as Coinbase SDK is not dispatching on main when calling UIApplication.openUrl()
            DispatchQueue.main.async {
                CoinbaseWalletSDK.shared.makeRequest(
                    .init(
                        actions: [
                            Action(jsonRpc: jsonRpc)
                        ]
                    )
                ) { result in
                    let response: W3MResponse
                    switch result {
                    case let .success(payload):
                        
                        switch payload.content.first {
                        case let .success(JSONString):
                            response = .init(result: .response(AnyCodable(JSONString)))
                        case let .failure(error):
                            response = .init(result: .error(.init(code: error.code, message: error.message)))
                        case .none:
                            response = .init(result: .error(.init(code: -1, message: "Empty response")))
                        }
                    case let .failure(error):
                        AppKit.config.onError(error)
                        
                        if let cbError = error as? ActionError {
                            response = .init(result: .error(.init(code: cbError.code, message: cbError.message)))
                        } else {
                            response = .init(result: .error(.init(code: -1, message: error.localizedDescription)))
                        }
                    }
                    
                    self.coinbaseResponseSubject.send(response)
                }
            }
        case .none:
            break
        }
    }
    
    /// For sending JSON-RPC requests to wallet.
    /// - Parameters:
    ///   - params: Parameters defining request and related session
    public func request(params: Request) async throws {
        do {
            try await signClient.request(params: params)
        } catch {
            AppKit.config.onError(error)
            throw error
        }
    }
    
    /// For a terminating a session
    ///
    /// Should Error:
    /// - When the session topic is not found
    /// - Parameters:
    ///   - topic: Session topic that you want to delete
    public func disconnect(topic: String) async throws {
        switch store.connectedWith {
        case .wc:
            do {
                try await signClient.disconnect(topic: topic)
                analyticsService.track(.DISCONNECT_SUCCESS)
            } catch {
                AppKit.config.onError(error)
                analyticsService.track(.DISCONNECT_ERROR)
                throw error
            }
        case .cb:
            if case let .failure(error) = CoinbaseWalletSDK.shared.resetSession() {
                analyticsService.track(.DISCONNECT_ERROR)
                throw error
            } else {
                analyticsService.track(.DISCONNECT_SUCCESS)
            }
        case .none:
            break
        }
    }
    
    /// Query sessions
    /// - Returns: All sessions
    public func getSessions() -> [Session] {
        signClient.getSessions()
    }
    
    /// Query pairings
    /// - Returns: All pairings
    public func getPairings() -> [Pairing] {
        pairingClient.getPairings()
    }
    
    /// Delete all stored data such as: pairings, sessions, keys
    ///
    /// - Note: Will unsubscribe from all topics
    public func cleanup() async throws {
        do {
            try await signClient.cleanup()
        } catch {
            AppKit.config.onError(error)
            throw error
        }
    }
    
    public func isConnectedToCoinbase() -> Bool {
        store.connectedWith == .cb
    }
    
    public func getSession() -> Session? {
        store.session
    }
    
    public func getAccount() -> W3MAccount? {
        store.account
    }
    
    public func selectAccount(_ account: W3MAccount, in session: Session) {
        store.connectedWith = .wc
        store.session = session
        store.account = account
    }
    
    public func getAddress() -> String? {
        guard let account = store.account else { return nil }
        
        return account.address
    }
    
    public func getSelectedChain() -> Chain? {
        guard let chain = store.selectedChain else {
            return nil
        }
        
        return chain
    }
    
    public func addChainPreset(_ chain: Chain) {
        ChainPresets.ethChains.append(chain)
    }
    
    public func selectChain(_ chain: Chain) {
        store.selectedChain = chain
    }
    
    @discardableResult
    public func handleDeeplink(_ url: URL) -> Bool {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
           queryItems.contains(where: { $0.name == "wc_ev" }) {
            do {
                try signClient.dispatchEnvelope(url.absoluteString)
                print("Handle deeplink Wallet Connect")
                return true
            } catch {
                print("Handle deeplink Wallet Connect with error \(error)")
                store.toast = .init(style: .error, message: error.localizedDescription)
                return false
            }
        }
        
        do {
            let handled = try CoinbaseWalletSDK.shared.handleResponse(url)
            print("Handle Coinbase SDK deeplink with response: \(handled)")
            return handled
        } catch {
            print("Handle Coinbase SDK deeplink with error \(error)")
            store.toast = .init(style: .error, message: error.localizedDescription)
            return false
        }
    }

    private func setUpConnectionEvents() {
        analyticsService.track(.MODAL_LOADED)

        signClient.sessionSettlePublisher.sink { [unowned self] session in
            self.analyticsService.track(.CONNECT_SUCCESS(method: analyticsService.method, name: session.peer.name))
        }.store(in: &disposeBag)


        signClient.sessionRejectionPublisher.sink { [unowned self] (_, reason) in
            self.analyticsService.track(.CONNECT_ERROR(message: reason.message))
        }.store(in: &disposeBag)
    }

    public func enableAnalytics() {
        analyticsService.enable()
    }

    public func disableAnalytics() {
        analyticsService.disable()
    }
}
