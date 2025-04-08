import Foundation
import Combine

protocol Dispatching {
    var onMessage: ((String) -> Void)? { get set }
    var isSocketConnected: Bool { get }
    var networkConnectionStatusPublisher: AnyPublisher<NetworkConnectionStatus, Never> { get }
    var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> { get }
    func protectedSend(_ string: String, connectUnconditionaly: Bool, completion: @escaping (Error?) -> Void)
    func protectedSend(_ string: String, connectUnconditionaly: Bool) async throws
    func connect() throws
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws
}

// Extension to provide default parameter value
extension Dispatching {
    func protectedSend(_ string: String, completion: @escaping (Error?) -> Void) {
        protectedSend(string, connectUnconditionaly: false, completion: completion)
    }
    
    func protectedSend(_ string: String) async throws {
        try await protectedSend(string, connectUnconditionaly: false)
    }

}

final class Dispatcher: NSObject, Dispatching {
    var onMessage: ((String) -> Void)?
    var socket: WebSocketConnecting
    var socketConnectionHandler: SocketConnectionHandler
    
    /// Timeout duration in seconds for waiting for the socket to connect during protectedSend.
    var connectionTimeoutDuration: TimeInterval = 30.0

    private let relayUrlFactory: RelayUrlFactory
    private let networkMonitor: NetworkMonitoring
    private let logger: ConsoleLogging
    private let socketStatusProvider: SocketStatusProviding

    var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> {
        socketStatusProvider.socketConnectionStatusPublisher
    }

    var networkConnectionStatusPublisher: AnyPublisher<NetworkConnectionStatus, Never> {
        networkMonitor.networkConnectionStatusPublisher
    }

    var isSocketConnected: Bool {
        return networkMonitor.isConnected
    }

    private let concurrentQueue = DispatchQueue(label: "com.walletconnect.sdk.dispatcher", qos: .utility, attributes: .concurrent)

    init(
        socketFactory: WebSocketFactory,
        relayUrlFactory: RelayUrlFactory,
        networkMonitor: NetworkMonitoring,
        socket: WebSocketConnecting,
        logger: ConsoleLogging,
        socketConnectionHandler: SocketConnectionHandler,
        socketStatusProvider: SocketStatusProviding
    ) {
        self.socketConnectionHandler = socketConnectionHandler
        self.relayUrlFactory = relayUrlFactory
        self.networkMonitor = networkMonitor
        self.logger = logger
        self.socket = socket
        self.socketStatusProvider = socketStatusProvider

        super.init()
        setUpWebSocketSession()
    }

    private func send(_ string: String, completion: @escaping (Error?) -> Void) {
        logger.debug("sending a socket frame")
        socket.write(string: string) {
            completion(nil)
        }
    }

    func protectedSend(_ string: String, connectUnconditionaly: Bool, completion: @escaping (Error?) -> Void) {
        logger.debug("will try to send a socket frame")
        // Check if the socket is already connected and ready to send
        if socket.isConnected {
            logger.debug("Socket is connected")
        } else {
            logger.debug("Socket is not connected")
        }

        if networkMonitor.isConnected {
            logger.debug("Network is connected")
        } else {
            logger.debug("Network is not connected")
        }

        if socket.isConnected && networkMonitor.isConnected {
            logger.debug("sending a socket frame")
            send(string, completion: completion)
            return
        }

        logger.debug("Socket is not connected, will try to connect to send a frame")
        // Start the connection process if not already connected
        Task {
            var cancellable: AnyCancellable? // Keep cancellable in scope
            defer { cancellable?.cancel() } // Ensure the subscription is cancelled on exit

            do {
                // Check for task cancellation
                try Task.checkCancellation()

                // Await the connection handler to establish the connection
                try await socketConnectionHandler.handleInternalConnect(unconditionaly: connectUnconditionaly)
                
                // Wait for the socket to connect with a timeout
                logger.debug("Waiting for socket connection status")
                
                // Use the configurable timeout duration
                let timeoutSeconds = self.connectionTimeoutDuration 
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    cancellable = self.socketStatusProvider.socketConnectionStatusPublisher
                        .setFailureType(to: Error.self) // Ensure the publisher can throw errors
                        .first(where: {
                            $0 == .connected
                        })
                        .timeout(.seconds(timeoutSeconds), scheduler: DispatchQueue.global(), customError: { NetworkError.connectionFailed })
                        .sink(receiveCompletion: { completionResult in
                            if case .failure(let error) = completionResult {
                                self.logger.debug("Failed to connect within timeout or other error: \(error)")
                                continuation.resume(throwing: error)
                            } // Success case handled by receiveValue
                        }, receiveValue: { _ in
                            self.logger.debug("Socket connected successfully")
                            continuation.resume()
                        })
                }
                
                // If we get here, the connection was successful within the timeout
                logger.debug("Connection successful, sending socket frame")
                send(string, completion: completion)
                
            } catch NetworkError.connectionFailed {
                logger.debug("Connection timed out")
                completion(NetworkError.connectionFailed)
            } catch is CancellationError {
                logger.debug("Task was cancelled")
                completion(CancellationError())
            } catch {
                logger.debug("Failed during connection or sending: \(error)")
                completion(error)
            }
        }
    }


    func protectedSend(_ string: String, connectUnconditionaly: Bool) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            var isResumed = false
            let syncQueue = DispatchQueue(label: "com.walletconnect.sdk.dispatcher.protectedSend")

            protectedSend(string, connectUnconditionaly: connectUnconditionaly) { error in
                syncQueue.sync {
                    guard !isResumed else {
                        return
                    }
                    isResumed = true

                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    func connect() throws {
        // Attempt to handle connection
        try socketConnectionHandler.handleConnect()
    }


    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {
        try socketConnectionHandler.handleDisconnect(closeCode: closeCode)
    }
}

// MARK: - Private functions
extension Dispatcher {
    private func setUpWebSocketSession() {
        socket.onText = { [unowned self] in
            self.onMessage?($0)
        }
    }


}
