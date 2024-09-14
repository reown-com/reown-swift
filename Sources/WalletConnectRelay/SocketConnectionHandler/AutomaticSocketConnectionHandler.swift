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

    // MARK: - Configuration

    var requestTimeout: TimeInterval = 15
    let maxImmediateAttempts = 3
    var periodicReconnectionInterval: TimeInterval = 5.0

    // MARK: - State Variables (Accessed on syncQueue)

    var reconnectionAttempts = 0
    var reconnectionTimer: DispatchSourceTimer?
    var isConnecting = false

    // MARK: - Queues

    private let syncQueue = DispatchQueue(label: "com.walletconnect.sdk.automatic_socket_connection.sync", qos: .utility)
    private var publishers = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        socket: WebSocketConnecting,
        networkMonitor: NetworkMonitoring = NetworkMonitor(),
        appStateObserver: AppStateObserving = AppStateObserver(),
        backgroundTaskRegistrar: BackgroundTaskRegistering = BackgroundTaskRegistrar(),
        subscriptionsTracker: SubscriptionsTracking,
        logger: ConsoleLogging,
        socketStatusProvider: SocketStatusProviding
    ) {
        self.appStateObserver = appStateObserver
        self.socket = socket
        self.networkMonitor = networkMonitor
        self.backgroundTaskRegistrar = backgroundTaskRegistrar
        self.logger = logger
        self.subscriptionsTracker = subscriptionsTracker
        self.socketStatusProvider = socketStatusProvider

        setUpStateObserving()
        setUpNetworkMonitoring()
        setUpSocketStatusObserving()
    }

    // MARK: - Connection Handling

    func connect() {
        syncQueue.async { [unowned self] in
            if isConnecting {
                logger.debug("Already connecting. Ignoring connect request.")
                return
            }
            logger.debug("Starting connection process.")
            isConnecting = true
            logger.debug("Socket request: \(socket.request.debugDescription)")
            socket.connect()
        }
    }

    // MARK: - Socket Status Observing

    private func setUpSocketStatusObserving() {
        logger.debug("Setting up socket status observing.")
        socketStatusProvider.socketConnectionStatusPublisher
            .sink { [unowned self] status in
                syncQueue.async { [unowned self] in
                    switch status {
                    case .connected:
                        logger.debug("Socket connected.")
                        isConnecting = false
                        reconnectionAttempts = 0 // Reset reconnection attempts on successful connection
                        stopPeriodicReconnectionTimer()
                    case .disconnected:
                        logger.debug("Socket disconnected.")
                        if isConnecting {
                            logger.debug("Was in connecting state when disconnected.")
                            handleFailedConnectionAndReconnectIfNeeded()
                        } else {
                            Task(priority: .high) {
                                await handleDisconnection()
                            }
                        }
                        isConnecting = false // Ensure isConnecting is reset
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

        reconnectionTimer?.setEventHandler { [unowned self] in
            logger.debug("Periodic reconnection attempt...")
            logger.debug("Socket request: \(socket.request.debugDescription)")
            if isConnecting {
                logger.debug("Already connecting. Skipping periodic reconnection attempt.")
                return
            }
            isConnecting = true
            socket.connect() // Attempt to reconnect
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
        appStateObserver.onWillEnterBackground = { [unowned self] in
            logger.debug("App will enter background. Registering background task.")
            registerBackgroundTask()
        }

        appStateObserver.onWillEnterForeground = { [unowned self] in
            logger.debug("App will enter foreground. Reconnecting if needed.")
            reconnectIfNeeded(willEnterForeground: true)
        }
    }

    // MARK: - Network Monitoring

    private func setUpNetworkMonitoring() {
        logger.debug("Setting up network monitoring.")
        networkMonitor.networkConnectionStatusPublisher
            .sink { [unowned self] networkConnectionStatus in
                if networkConnectionStatus == .connected {
                    logger.debug("Network connected. Reconnecting if needed.")
                    reconnectIfNeeded()
                }
            }
            .store(in: &publishers)
    }

    // MARK: - Background Task Handling

    private func registerBackgroundTask() {
        logger.debug("Registering background task.")
        backgroundTaskRegistrar.register(name: "Finish Network Tasks") { [unowned self] in
            endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        logger.debug("Ending background task. Disconnecting socket.")
        socket.disconnect()
    }

    // MARK: - Reconnection Logic

    func reconnectIfNeeded(willEnterForeground: Bool = false) {
        Task { [unowned self] in
            let appState = await appStateObserver.currentState
            logger.debug("App state: \(appState)")

            if !willEnterForeground {
                guard appState == .foreground else {
                    logger.debug("App is not in the foreground. Reconnection will not be attempted.")
                    return
                }
            } else {
                logger.debug("Bypassing app state check due to willEnterForeground = true")
            }

            syncQueue.async { [unowned self] in
                logger.debug("Checking if reconnection is needed: connected: \(socket.isConnected), isSubscribed: \(subscriptionsTracker.isSubscribed())")

                if !socket.isConnected {
                    logger.debug("Socket is not connected, Reconnecting...")
                    connect()
                } else {
                    logger.debug("Will not attempt to reconnect")
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

        // Start the connection process immediately if not already connecting
        syncQueue.async { [unowned self] in
            if !isConnecting {
                logger.debug("Not already connecting. Will start connection.")
                isConnecting = true

                logger.debug("Starting connection process.")
                logger.debug("Socket request: \(socket.request.debugDescription)")

                // Start the connection
                socket.connect()
            } else {
                logger.debug("Already connecting. Will not start new connection.")
            }
        }
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
                .setFailureType(to: NetworkError.self) // Set failure type to NetworkError
                .timeout(.seconds(requestTimeout), scheduler: DispatchQueue.global(), customError: { NetworkError.connectionFailed })
                .sink(receiveCompletion: { [unowned self] completion in
                    guard !isResumed else { return } // Ensure continuation is only resumed once
                    isResumed = true
                    cancellable?.cancel() // Cancel the subscription to prevent further events

                    if case .failure(let error) = completion {
                        logger.debug("Connection failed with error: \(error).")
                        syncQueue.async { [unowned self] in
                            isConnecting = false
                            handleFailedConnectionAndReconnectIfNeeded() // Trigger reconnection
                        }
                        continuation.resume(throwing: error) // Timeout or connection failure
                    }
                }, receiveValue: { [unowned self] status in
                    guard !isResumed else { return } // Ensure continuation is only resumed once
                    if status == .connected {
                        logger.debug("Connection succeeded.")
                        isResumed = true
                        cancellable?.cancel() // Cancel the subscription to prevent further events
                        syncQueue.async { [unowned self] in
                            isConnecting = false
                        }
                        continuation.resume() // Successfully connected
                    } else if status == .disconnected {
                        attempts += 1
                        logger.debug("Disconnection observed, incrementing attempts to \(attempts)")

                        if attempts >= maxAttempts {
                            logger.debug("Max attempts reached. Failing with connection error.")
                            isResumed = true
                            cancellable?.cancel() // Cancel the subscription to prevent further events
                            syncQueue.async { [unowned self] in
                                isConnecting = false
                                handleFailedConnectionAndReconnectIfNeeded() // Trigger reconnection
                            }
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
