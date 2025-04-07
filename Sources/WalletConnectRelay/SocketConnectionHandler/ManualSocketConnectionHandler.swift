import Foundation
import Combine

class ManualSocketConnectionHandler: SocketConnectionHandler {
    // MARK: - Dependencies
    private let socket: WebSocketConnecting
    private let logger: ConsoleLogging
    private let subscriptionsTracker: SubscriptionsTracking
    private let clientIdAuthenticator: ClientIdAuthenticating
    private let socketStatusProvider: SocketStatusProviding
    
    // MARK: - Configuration
    var isConnecting = false
    
    // MARK: - Queues
    private let syncQueue = DispatchQueue(label: "com.walletconnect.sdk.manual_socket_connection.sync", qos: .utility)
    private var publishers = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        socket: WebSocketConnecting,
        logger: ConsoleLogging,
        subscriptionsTracker: SubscriptionsTracking,
        clientIdAuthenticator: ClientIdAuthenticating,
        socketStatusProvider: SocketStatusProviding
    ) {
        self.socket = socket
        self.logger = logger
        self.subscriptionsTracker = subscriptionsTracker
        self.clientIdAuthenticator = clientIdAuthenticator
        self.socketStatusProvider = socketStatusProvider
        
        setUpSocketStatusObserving()
    }
    
    // MARK: - Socket Status Observing
    private func setUpSocketStatusObserving() {
        logger.debug("Setting up socket status observing.")
        socketStatusProvider.socketConnectionStatusPublisher
            .sink { [weak self] status in
                guard let self = self else { return }
                self.syncQueue.async { [weak self] in
                    guard let self = self else { return }
                    switch status {
                    case .connected:
                        self.logger.debug("Socket connected.")
                        self.isConnecting = false
                    case .disconnected:
                        self.logger.debug("Socket disconnected.")
                        self.isConnecting = false
                    }
                }
            }
            .store(in: &publishers)
    }
    
    // MARK: - Connection Handling
    func handleConnect() throws {
        guard subscriptionsTracker.isSubscribed() else {
            logger.debug("No active subscriptions. Skipping connection.")
            return
        }
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isConnecting {
                self.logger.debug("Already connecting. Ignoring connect request.")
                return
            }
            
            self.logger.debug("Starting connection process.")
            self.isConnecting = true
            self.refreshTokenIfNeeded()
            self.socket.connect()
        }
    }
    
    private func refreshTokenIfNeeded() {
        guard let authorizationHeader = socket.request.allHTTPHeaderFields?["Authorization"] else { return }
        
        // Remove "Bearer " prefix if it exists
        var token = authorizationHeader
        if token.hasPrefix("Bearer ") {
            token = String(token.dropFirst("Bearer ".count))
        }
        
        do {
            // Parse the URL and extract only the base URL (without query parameters)
            var urlComponents = URLComponents(url: socket.request.url!, resolvingAgainstBaseURL: false)
            urlComponents?.query = nil
            let baseUrlString = urlComponents?.url?.absoluteString ?? socket.request.url!.absoluteString
            
            // Refresh the token with just the base URL
            let refreshedToken = try clientIdAuthenticator.refreshTokenIfNeeded(token: token, url: baseUrlString)
            let newAuthorizationHeader = "Bearer \(refreshedToken)"
            socket.request.allHTTPHeaderFields?["Authorization"] = newAuthorizationHeader
        } catch {
            logger.error("Error refreshing token: \(error)")
        }
    }
    
    // MARK: - SocketConnectionHandler Protocol
    func handleDisconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.isConnecting = false
            self.socket.disconnect()
        }
    }
    
    func handleInternalConnect() async throws {
        try handleConnect()
    }
}
