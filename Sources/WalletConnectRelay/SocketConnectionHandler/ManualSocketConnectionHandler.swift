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
    private let defaultTimeout: Int = 60
    private let maxImmediateAttempts = 3
    private var reconnectionAttempts = 0
    private var reconnectionTimer: DispatchSourceTimer?
    private var isConnecting = false
    
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
                        self.reconnectionAttempts = 0
                        self.stopPeriodicReconnectionTimer()
                    case .disconnected:
                        self.logger.debug("Socket disconnected.")
                        if self.isConnecting {
                            self.logger.debug("Was in connecting state when disconnected.")
                            self.handleFailedConnectionAndReconnectIfNeeded()
                        }
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
    
    private func handleFailedConnectionAndReconnectIfNeeded() {
        isConnecting = false
        if reconnectionAttempts < maxImmediateAttempts {
            reconnectionAttempts += 1
            logger.debug("Immediate reconnection attempt \(reconnectionAttempts) of \(maxImmediateAttempts)")
            connectSocketWithFreshToken()
        } else {
            logger.debug("Max immediate reconnection attempts reached. Switching to periodic reconnection.")
            startPeriodicReconnectionTimerIfNeeded()
        }
    }
    
    private func startPeriodicReconnectionTimerIfNeeded() {
        guard reconnectionTimer == nil else {
            logger.debug("Reconnection timer is already running.")
            return
        }
        
        logger.debug("Starting periodic reconnection timer.")
        reconnectionTimer = DispatchSource.makeTimerSource(queue: syncQueue)
        let initialDelay: DispatchTime = .now() + 5.0 // 5 seconds interval
        
        reconnectionTimer?.schedule(deadline: initialDelay, repeating: 5.0)
        
        reconnectionTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.logger.debug("Periodic reconnection attempt...")
            if self.isConnecting {
                self.logger.debug("Already connecting. Skipping periodic reconnection attempt.")
                return
            }
            self.isConnecting = true
            self.connectSocketWithFreshToken()
        }
        
        reconnectionTimer?.resume()
    }
    
    private func stopPeriodicReconnectionTimer() {
        logger.debug("Stopping periodic reconnection timer.")
        reconnectionTimer?.cancel()
        reconnectionTimer = nil
    }
    
    private func connectSocketWithFreshToken() {
        refreshTokenIfNeeded()
        socket.connect()
    }
    
    // MARK: - SocketConnectionHandler Protocol
    func handleDisconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.stopPeriodicReconnectionTimer()
            self.reconnectionAttempts = 0
            self.isConnecting = false
            self.socket.disconnect()
        }
    }
    
    func handleInternalConnect() async throws {
        // No operation - manual mode doesn't support internal connection
    }
    
    func handleDisconnection() async {
        // No operation - manual mode doesn't support automatic reconnection
    }
}
