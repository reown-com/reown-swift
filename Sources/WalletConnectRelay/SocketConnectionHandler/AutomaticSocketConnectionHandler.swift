#if os(iOS)
import UIKit
#endif
import Foundation
import Combine

class AutomaticSocketConnectionHandler {

    enum Errors: Error {
        case manualSocketConnectionForbidden, manualSocketDisconnectionForbidden
    }

    private let socket: WebSocketConnecting
    private let appStateObserver: AppStateObserving
    private let networkMonitor: NetworkMonitoring
    private let backgroundTaskRegistrar: BackgroundTaskRegistering
    private let logger: ConsoleLogging
    private let subscriptionsTracker: SubscriptionsTracking
    private let socketStatusProvider: SocketStatusProviding

    private var publishers = Set<AnyCancellable>()
    private let concurrentQueue = DispatchQueue(label: "com.walletconnect.sdk.automatic_socket_connection", qos: .utility, attributes: .concurrent)

    var reconnectionAttempts = 0
    let maxImmediateAttempts = 3
    var periodicReconnectionInterval: TimeInterval = 5.0
    var reconnectionTimer: DispatchSourceTimer?
    var isConnecting = false

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

    func connect() {
        // Start the connection process
        logger.debug("Starting connection process.")
        isConnecting = true
        socket.connect()
    }

    private func setUpSocketStatusObserving() {
        logger.debug("Setting up socket status observing.")
        socketStatusProvider.socketConnectionStatusPublisher
            .sink { [unowned self] status in
                switch status {
                case .connected:
                    logger.debug("Socket connected.")
                    isConnecting = false
                    reconnectionAttempts = 0 // Reset reconnection attempts on successful connection
                    stopPeriodicReconnectionTimer() // Stop any ongoing periodic reconnection attempts
                case .disconnected:
                    logger.debug("Socket disconnected.")
                    if isConnecting {
                        // Handle reconnection logic
                        handleFailedConnectionAndReconnectIfNeeded()
                    } else {
                        Task(priority: .high) {
                            await handleDisconnection()
                        }
                    }
                }
            }
            .store(in: &publishers)
    }

    private func handleFailedConnectionAndReconnectIfNeeded() {
        if reconnectionAttempts < maxImmediateAttempts {
            reconnectionAttempts += 1
            logger.debug("Immediate reconnection attempt \(reconnectionAttempts) of \(maxImmediateAttempts)")
            socket.connect()
        } else {
            logger.debug("Max immediate reconnection attempts reached. Switching to periodic reconnection every \(periodicReconnectionInterval) seconds.")
            startPeriodicReconnectionTimerIfNeeded()
        }
    }

    private func stopPeriodicReconnectionTimer() {
        logger.debug("Stopping periodic reconnection timer.")
        reconnectionTimer?.cancel()
        reconnectionTimer = nil
    }

    private func startPeriodicReconnectionTimerIfNeeded() {
        guard reconnectionTimer == nil else {
            logger.debug("Reconnection timer is already running.")
            return
        }

        logger.debug("Starting periodic reconnection timer.")
        reconnectionTimer = DispatchSource.makeTimerSource(queue: concurrentQueue)
        let initialDelay: DispatchTime = .now() + periodicReconnectionInterval

        reconnectionTimer?.schedule(deadline: initialDelay, repeating: periodicReconnectionInterval)

        reconnectionTimer?.setEventHandler { [unowned self] in
            logger.debug("Periodic reconnection attempt...")
            socket.connect() // Attempt to reconnect

            // The socketConnectionStatusPublisher handler will stop the timer and reset states if connection is successful
        }

        reconnectionTimer?.resume()
    }

    private func setUpStateObserving() {
        logger.debug("Setting up app state observing.")
        appStateObserver.onWillEnterBackground = { [unowned self] in
            logger.debug("App will enter background. Registering background task.")
            registerBackgroundTask()
        }

        appStateObserver.onWillEnterForeground = { [unowned self] in
            logger.debug("App will enter foreground. Reconnecting if needed.")
            reconnectIfNeeded()
        }
    }

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

    func reconnectIfNeeded() {
        // Check if client has active subscriptions and only then attempt to reconnect
        logger.debug("Checking if reconnection is needed.")
        if !socket.isConnected && subscriptionsTracker.isSubscribed() {
            logger.debug("Socket is not connected, but there are active subscriptions. Reconnecting...")
            connect()
        } else {
            logger.debug("Will not attempt to reconnect")
        }
    }

    var requestTimeout: TimeInterval = 15
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
        if !isConnecting {
            logger.debug("Not already connecting. Starting connection.")
            connect() // This will set isConnecting = true and attempt to connect
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
                .timeout(.seconds(requestTimeout), scheduler: concurrentQueue, customError: { NetworkError.connectionFailed })
                .sink(receiveCompletion: { [unowned self] completion in
                    guard !isResumed else { return } // Ensure continuation is only resumed once
                    isResumed = true
                    cancellable?.cancel() // Cancel the subscription to prevent further events

                    // Handle only the failure case, as .finished is not expected to be meaningful here
                    if case .failure(let error) = completion {
                        logger.debug("Connection failed with error: \(error).")
                        continuation.resume(throwing: error) // Timeout or connection failure
                    }
                }, receiveValue: { [unowned self] status in
                    guard !isResumed else { return } // Ensure continuation is only resumed once
                    if status == .connected {
                        logger.debug("Connection succeeded.")
                        isResumed = true
                        cancellable?.cancel() // Cancel the subscription to prevent further events
                        continuation.resume() // Successfully connected
                    } else if status == .disconnected {
                        attempts += 1
                        logger.debug("Disconnection observed, incrementing attempts to \(attempts)")

                        if attempts >= maxAttempts {
                            logger.debug("Max attempts reached. Failing with connection error.")
                            isResumed = true
                            cancellable?.cancel() // Cancel the subscription to prevent further events
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
//        guard await appStateObserver.currentState == .foreground else {
//            logger.debug("App is not in foreground. No reconnection will be attempted.")
//            return
//        }
        reconnectIfNeeded()
    }
}
