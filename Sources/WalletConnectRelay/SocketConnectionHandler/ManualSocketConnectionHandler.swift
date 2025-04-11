import Foundation
import Combine

class ManualSocketConnectionHandler: SocketConnectionHandler {
    enum Errors: Error {
        case internalConnectionRejected
    }
    // MARK: - Dependencies
    private let socket: WebSocketConnecting
    private let logger: ConsoleLogging
    private let topicsTracker: TopicsTracking
    private let clientIdAuthenticator: ClientIdAuthenticating
    private let socketStatusProvider: SocketStatusProviding
    
    // MARK: - Configuration
    var isConnecting = false
    
    /// Timeout duration in seconds for waiting for the socket to connect during handleInternalConnect.
    var connectionTimeout: TimeInterval = 45.0
    
    // MARK: - Queues
    private let syncQueue = DispatchQueue(label: "com.walletconnect.sdk.manual_socket_connection.sync", qos: .utility)
    private var publishers = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        socket: WebSocketConnecting,
        logger: ConsoleLogging,
        topicsTracker: TopicsTracking,
        clientIdAuthenticator: ClientIdAuthenticating,
        socketStatusProvider: SocketStatusProviding
    ) {
        self.socket = socket
        self.logger = logger
        self.topicsTracker = topicsTracker
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
        // Only connect if we're tracking at least one topic
        guard topicsTracker.isTrackingAnyTopics() else {
            logger.debug("No topics being tracked. Skipping connection.")
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
    
    func handleInternalConnect(unconditionally: Bool) async throws {
        // Guard to ensure we only connect when unconditionally = true
        guard unconditionally else {
            logger.debug("Not connecting on internal connect (unconditionally=false)")
            throw Errors.internalConnectionRejected
        }
        
        // Connect regardless of whether we're tracking any topics - handles publish events
        logger.debug("Starting unconditional internal connection process.")
        
        if socket.isConnected {
            logger.debug("Socket is already connected. Will not start new connection.")
            return
        }

        // Set connecting state on sync queue
        let shouldStartConnect = syncQueue.sync { [weak self] () -> Bool in
            guard let self = self else {
                return false
            }
            if !self.isConnecting {
                logger.debug("Not already connecting. Will set isConnecting = true and proceed.")
                self.isConnecting = true
                return true
            } else {
                logger.debug("Already connecting. Will not start new connection.")
                return false
            }
        }

        guard shouldStartConnect else {
            logger.debug("Another connection attempt is already in progress, returning early.")
            return
        }

        // Prepare for connection
        refreshTokenIfNeeded()
        
        // Connect the socket
        logger.debug("Starting socket connection.")
        socket.connect()
        
        // Set up a publisher that we can use to monitor the connection status
        let connectionStatusPublisher = socketStatusProvider.socketConnectionStatusPublisher
            .share()
            .makeConnectable()
        
        let connection = connectionStatusPublisher.connect()
        
        defer {
            logger.debug("Cancelling connection status publisher.")
            connection.cancel()
            
            syncQueue.async {
                self.isConnecting = false
            }
        }
        
        // Use the configurable timeout
        let timeout: TimeInterval = self.connectionTimeout
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var cancellable: AnyCancellable?
            
            cancellable = connectionStatusPublisher
                .setFailureType(to: NetworkError.self)
                .timeout(.seconds(timeout), scheduler: DispatchQueue.global(), customError: {
                    self.logger.debug("Connection timeout triggered after \(timeout) seconds.")
                    return NetworkError.connectionFailed
                })
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.logger.debug("Connection failed with error: \(error).")
                            cancellable?.cancel()
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { status in
                        if status == .connected {
                            self.logger.debug("Connection succeeded.")
                            cancellable?.cancel()
                            continuation.resume()
                        }
                    }
                )
        }
    }
}
