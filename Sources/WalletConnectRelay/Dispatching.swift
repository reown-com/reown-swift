import Foundation
import Combine

protocol Dispatching {
    var onMessage: ((String) -> Void)? { get set }
    var isSocketConnected: Bool { get }
    var networkConnectionStatusPublisher: AnyPublisher<NetworkConnectionStatus, Never> { get }
    var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> { get }
    func protectedSend(_ string: String, completion: @escaping (Error?) -> Void)
    func protectedSend(_ string: String) async throws
    func connect() throws
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws
}

final class Dispatcher: NSObject, Dispatching {
    var onMessage: ((String) -> Void)?
    var socket: WebSocketConnecting
    var socketConnectionHandler: SocketConnectionHandler

    private let defaultTimeout: Int = 15
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
        socket.write(string: string) {
            completion(nil)
        }
    }

    func protectedSend(_ string: String, completion: @escaping (Error?) -> Void) {
        logger.debug("will try to send a socket frame")
        // Check if the socket is already connected and ready to send
        if socket.isConnected && networkMonitor.isConnected {
            logger.debug("sending a socket frame")
            send(string, completion: completion)
            return
        }

        logger.debug("Socket is not connected, will try to connect to send a frame")
        // Start the connection process if not already connected
        Task {
            do {
                // Check for task cancellation
                try Task.checkCancellation()
                
                // Await the connection handler to establish the connection
                try await socketConnectionHandler.handleInternalConnect()
                
                logger.debug("internal connect successful, will try to send a socket frame")
                // If successful, send the message
                send(string, completion: completion)
            } catch is CancellationError {
                logger.debug("Task was cancelled")
                completion(CancellationError())
            } catch {
                logger.debug("failed to handle internal connect")
                // If an error occurs during connection, complete with that error
                completion(error)
            }
        }
    }


    func protectedSend(_ string: String) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            var isResumed = false
            let syncQueue = DispatchQueue(label: "com.walletconnect.sdk.dispatcher.protectedSend")

            protectedSend(string) { error in
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
