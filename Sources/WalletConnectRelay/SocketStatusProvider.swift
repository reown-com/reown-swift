
import Foundation
import Combine

protocol SocketStatusProviding {
    var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> { get }
}

class SocketStatusProvider: SocketStatusProviding {
    private var socket: WebSocketConnecting
    private let logger: ConsoleLogging
    private let socketConnectionStatusPublisherSubject = CurrentValueSubject<SocketConnectionStatus, Never>(.disconnected)

    var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> {
        socketConnectionStatusPublisherSubject.eraseToAnyPublisher()
    }

    init(socket: WebSocketConnecting,
         logger: ConsoleLogging) {
        self.socket = socket
        self.logger = logger
        setUpSocketConnectionObserving()
    }

    private func setUpSocketConnectionObserving() {
        socket.onConnect = { [unowned self] in
            self.socketConnectionStatusPublisherSubject.send(.connected)
        }
        socket.onDisconnect = { [unowned self] error in
            if let error = error {
                logger.debug("Socket disconnected with error: \(error.localizedDescription)")
                logger.debug("Error type: \(type(of: error))")

                let errorMirror = Mirror(reflecting: error)

                var errorType = "Unknown"
                var errorMessage = error.localizedDescription
                var errorCode = "N/A"

                for child in errorMirror.children {
                    if let label = child.label {
                        switch label {
                        case "type":
                            errorType = "\(child.value)"
                        case "message":
                            errorMessage = "\(child.value)"
                        case "code":
                            errorCode = "\(child.value)"
                        default:
                            break
                        }
                    }
                }

                logger.debug("WSError type: \(errorType)")
                logger.debug("WSError message: \(errorMessage)")
                logger.debug("WSError code: \(errorCode)")

                let errorDetails = errorMirror.children.compactMap { child -> String? in
                    guard let label = child.label else { return nil }
                    return "\(label): \(child.value)"
                }.joined(separator: ", ")

                logger.debug("Error details: \(errorDetails)")
            } else {
                logger.debug("Socket disconnected with unknown error.")
            }
            self.socketConnectionStatusPublisherSubject.send(.disconnected)
        }
    }
}

#if DEBUG
final class SocketStatusProviderMock: SocketStatusProviding {
    private var socketConnectionStatusPublisherSubject = PassthroughSubject<SocketConnectionStatus, Never>()

    var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> {
        socketConnectionStatusPublisherSubject.eraseToAnyPublisher()
    }

    func simulateConnectionStatus(_ status: SocketConnectionStatus) {
        socketConnectionStatusPublisherSubject.send(status)
    }
}
#endif
