#if os(iOS)
import UIKit
#endif
import Foundation
import Combine

class AutomaticSocketConnectionHandler {

    enum Errors: Error {
        case manualSocketConnectionForbidden, manualSocketDisconnectionForbidden
    }

    // MARK: - Dependencies

    private let socket: WebSocketConnecting
    private let appStateObserver: AppStateObserving
    private let networkMonitor: NetworkMonitoring
    private let backgroundTaskRegistrar: BackgroundTaskRegistering
    private let logger: ConsoleLogging
    private let subscriptionsTracker: SubscriptionsTracking
    private let socketStatusProvider: SocketStatusProviding
    private let clientIdAuthenticator: ClientIdAuthenticating

    // MARK: - Configuration

    var requestTimeout: TimeInterval = 15
    let maxImmediateAttempts = 3
    var periodicReconnectionInterval: TimeInterval = 5.0

    // MARK: - State Variables (Accessed on syncQueue)

    var reconnectionAttempts = 0
    var reconnectionTimer: DispatchSourceTimer?
    var isConnecting = false

    // MARK: - Queues

    let syncQueue = DispatchQueue(label: "com.walletconnect.sdk.automatic_socket_connection.sync", qos: .utility)
    private var publishers = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        socket: WebSocketConnecting,
        networkMonitor: NetworkMonitoring = NetworkMonitor(),
        appStateObserver: AppStateObserving = AppStateObserver(),
        backgroundTaskRegistrar: BackgroundTaskRegistering = BackgroundTaskRegistrar(),
        subscriptionsTracker: SubscriptionsTracking,
        logger: ConsoleLogging,
        socketStatusProvider: SocketStatusProviding,
        clientIdAuthenticator: ClientIdAuthenticating
    ) {
        self.appStateObserver = appStateObserver
        self.socket = socket
        self.networkMonitor = networkMonitor
        self.backgroundTaskRegistrar = backgroundTaskRegistrar
        self.logger = logger
        self.subscriptionsTracker = subscriptionsTracker
        self.socketStatusProvider = socketStatusProvider
        self.clientIdAuthenticator = clientIdAuthenticator

        setUpStateObserving()
        setUpNetworkMonitoring()
        setUpSocketStatusObserving()
    }

    // MARK: - Connection Handling

    func connect() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isConnecting {
                self.logger.debug("Already connecting. Ignoring connect request.")
                return
            }
            self.logger.debug("Starting connection process.")
            self.isConnecting = true
            self.logger.debug("Socket request: \(self.socket.request.debugDescription)")
            self.connectSocketWithFreshToken()
        }
    }

    private func connectSocketWithFreshToken() {
        refreshTokenIfNeeded()
        socket.connect()
    }

    private func refreshTokenIfNeeded() {
        guard let authorizationHeader = socket.request.allHTTPHeaderFields?["Authorization"] else { return }

        // Remove "Bearer " prefix if it exists
        var token = authorizationHeader
        if token.hasPrefix("Bearer ") {
            token = String(token.dropFirst("Bearer ".count))
        }

        do {
            let refreshedToken = try clientIdAuthenticator.refreshTokenIfNeeded(token: token, url: socket.request.url!.absoluteString)
            let newAuthorizationHeader = "Bearer \(refreshedToken)"
            socket.request.allHTTPHeaderFields?["Authorization"] = newAuthorizationHeader
        } catch {
            // Handle error appropriately
            logger.error("Error refreshing token: \(error)")
        }
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
                        self.reconnectionAttempts = 0 // Reset reconnection attempts on successful connection
                        self.stopPeriodicReconnectionTimer()
                    case .disconnected:
                        self.logger.debug("Socket disconnected.")
                        if self.isConnecting {
                            self.logger.debug("Was in connecting state when disconnected.")
                            self.handleFailedConnectionAndReconnectIfNeeded()
                        } else {
                            Task(priority: .high) { [weak self] in
                                await self?.handleDisconnection()
                            }
                        }
                        self.isConnecting = false // Ensure isConnecting is reset
                    }
                }
            }
            .store(in: &publishers)
    }

    private func handleFailedConnectionAndReconnectIfNeeded() {
        // This method is called within syncQueue
        isConnecting = false
        if reconnectionAttempts < maxImmediateAttempts {
            reconnectionAttempts += 1
            logger.debug("Immediate reconnection attempt \(reconnectionAttempts) of \(maxImmediateAttempts)")
            logger.debug("Socket request: \(socket.request.debugDescription)")
            // Attempt to reconnect
            connect() // connect() will check isConnecting
        } else {
            logger.debug("Max immediate reconnection attempts reached. Switching to periodic reconnection every \(periodicReconnectionInterval) seconds.")
            startPeriodicReconnectionTimerIfNeeded()
        }
    }

    private func startPeriodicReconnectionTimerIfNeeded() {
        // This method is called within syncQueue
        guard reconnectionTimer == nil else {
            logger.debug("Reconnection timer is already running.")
            return
        }

        logger.debug("Starting periodic reconnection timer.")
        reconnectionTimer = DispatchSource.makeTimerSource(queue: syncQueue)
        let initialDelay: DispatchTime = .now() + periodicReconnectionInterval

        reconnectionTimer?.schedule(deadline: initialDelay, repeating: periodicReconnectionInterval)

        reconnectionTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.logger.debug("Periodic reconnection attempt...")
            self.logger.debug("Socket request: \(self.socket.request.debugDescription)")
            if self.isConnecting {
                self.logger.debug("Already connecting. Skipping periodic reconnection attempt.")
                return
            }
            self.isConnecting = true
            self.connectSocketWithFreshToken() // Attempt to reconnect
            // The socketConnectionStatusPublisher handler will stop the timer and reset states if connection is successful
        }

        reconnectionTimer?.resume()
    }

    private func stopPeriodicReconnectionTimer() {
        // This method is called within syncQueue
        logger.debug("Stopping periodic reconnection timer.")
        reconnectionTimer?.cancel()
        reconnectionTimer = nil
    }

    // MARK: - App State Observing

    private func setUpStateObserving() {
        logger.debug("Setting up app state observing.")
        appStateObserver.onWillEnterBackground = { [weak self] in
            guard let self = self else { return }
            self.logger.debug("App will enter background. Registering background task.")
            self.registerBackgroundTask()
        }

        appStateObserver.onWillEnterForeground = { [weak self] in
            guard let self = self else { return }
            self.logger.debug("App will enter foreground. Reconnecting if needed.")
            self.reconnectIfNeeded(willEnterForeground: true)
        }
    }

    // MARK: - Network Monitoring

    private func setUpNetworkMonitoring() {
        logger.debug("Setting up network monitoring.")
        networkMonitor.networkConnectionStatusPublisher
            .sink { [weak self] networkConnectionStatus in
                guard let self = self else { return }
                if networkConnectionStatus == .connected {
                    self.logger.debug("Network connected. Reconnecting if needed.")
                    self.reconnectIfNeeded()
                }
            }
            .store(in: &publishers)
    }

    // MARK: - Background Task Handling

    private func registerBackgroundTask() {
        logger.debug("Registering background task.")
        backgroundTaskRegistrar.register(name: "Finish Network Tasks") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        logger.debug("Ending background task. Disconnecting socket.")
        socket.disconnect()
    }

    // MARK: - Reconnection Logic

    func reconnectIfNeeded(willEnterForeground: Bool = false) {
        Task { [weak self] in
            guard let self = self else { return }
            let appState = await self.appStateObserver.currentState
            self.logger.debug("App state: \(appState)")

            if !willEnterForeground {
                guard appState == .foreground else {
                    self.logger.debug("App is not in the foreground. Reconnection will not be attempted.")
                    return
                }
            } else {
                self.logger.debug("Bypassing app state check due to willEnterForeground = true")
            }

            self.syncQueue.async { [weak self] in
                guard let self = self else { return }
                self.logger.debug("Checking if reconnection is needed: connected: \(self.socket.isConnected), isSubscribed: \(self.subscriptionsTracker.isSubscribed())")

                if !self.socket.isConnected && self.subscriptionsTracker.isSubscribed() {
                    self.logger.debug("Socket is not connected, Reconnecting...")
                    self.connect()
                } else {
                    self.logger.debug("Will not attempt to reconnect")
                }
            }
        }
    }
}

// MARK: - SocketConnectionHandler

extension AutomaticSocketConnectionHandler: SocketConnectionHandler {
    func handleInternalConnect() async throws {
        logger.debug("Handling internal connection.")
        let maxAttempts = maxImmediateAttempts
        var attempts = 0
        var isResumed = false // Track if continuation has been resumed
        let requestTimeout = self.requestTimeout // Timeout set at the class level

        var shouldStartConnect = false

        // Start the connection process immediately if not already connecting
        syncQueue.sync { [weak self] in
            guard let self = self else { return }
            if !self.isConnecting {
                self.logger.debug("Not already connecting. Will start connection.")
                self.isConnecting = true
                shouldStartConnect = true
            } else {
                self.logger.debug("Already connecting. Will not start new connection.")
            }
        }

        if !shouldStartConnect {
            // Exit the function early since a connection is already in progress
            return
        }

        // Proceed to start the connection
        logger.debug("Starting connection process.")
        logger.debug("Socket request: \(socket.request.debugDescription)")
        connectSocketWithFreshToken()

        // Use Combine publisher to monitor connection status
        let connectionStatusPublisher = socketStatusProvider.socketConnectionStatusPublisher
            .share()
            .makeConnectable()

        let connection = connectionStatusPublisher.connect()

        // Ensure connection is canceled when done
        defer {
            logger.debug("Cancelling connection status publisher.")
            connection.cancel()
        }

        // Use a Combine publisher to monitor disconnection and timeout
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var cancellable: AnyCancellable?

            cancellable = connectionStatusPublisher
                .setFailureType(to: NetworkError.self)
                .timeout(.seconds(requestTimeout), scheduler: DispatchQueue.global(), customError: { NetworkError.connectionFailed })
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    guard !isResumed else { return } // Ensure continuation is only resumed once
                    isResumed = true
                    cancellable?.cancel() // Cancel the subscription to prevent further events

                    if case .failure(let error) = completion {
                        self.logger.debug("Connection failed with error: \(error).")
                        continuation.resume(throwing: error) // Timeout or connection failure
                    }
                }, receiveValue: { [weak self] status in
                    guard let self = self else { return }
                    guard !isResumed else { return } // Ensure continuation is only resumed once
                    if status == .connected {
                        self.logger.debug("Connection succeeded.")
                        isResumed = true
                        cancellable?.cancel() // Cancel the subscription to prevent further events
                        self.syncQueue.async { [weak self] in
                            guard let self = self else { return }
                            self.isConnecting = false
                        }
                        continuation.resume() // Successfully connected
                    } else if status == .disconnected {
                        attempts += 1
                        self.logger.debug("Disconnection observed, incrementing attempts to \(attempts)")

                        if attempts >= maxAttempts {
                            self.logger.debug("Max attempts reached. Failing with connection error.")
                            isResumed = true
                            cancellable?.cancel() // Cancel the subscription to prevent further events
                            self.syncQueue.async { [weak self] in
                                guard let self = self else { return }
                                self.isConnecting = false
                                self.handleFailedConnectionAndReconnectIfNeeded() // Trigger reconnection
                            }
                            self.logger.debug("Will throw an error \(NetworkError.connectionFailed)")
                            continuation.resume(throwing: NetworkError.connectionFailed)
                        }
                    }
                })

            // Store cancellable to keep it alive
            self.publishers.insert(cancellable!)
        }
    }

    func handleConnect() throws {
        logger.debug("Manual connect requested but forbidden.")
        throw Errors.manualSocketConnectionForbidden
    }

    func handleDisconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {
        logger.debug("Manual disconnect requested but forbidden.")
        throw Errors.manualSocketDisconnectionForbidden
    }

    func handleDisconnection() async {
        logger.debug("Handling disconnection.")
        reconnectIfNeeded()
    }
}
