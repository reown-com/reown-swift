import Foundation
import JSONRPC
import Combine
@testable import WalletConnectRelay

class DispatcherMock: Dispatching {
    var isSocketConnected: Bool = true
    

    private var publishers = Set<AnyCancellable>()
    private let socketConnectionStatusPublisherSubject = CurrentValueSubject<SocketConnectionStatus, Never>(.disconnected)
    var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> {
        return socketConnectionStatusPublisherSubject.eraseToAnyPublisher()
    }
    var networkConnectionStatusPublisher: AnyPublisher<NetworkConnectionStatus, Never> {
        return Just(.connected).eraseToAnyPublisher()
    }

    var sent = false
    var lastMessage: String = ""
    var onMessage: ((String) -> Void)?
    var lastConnectUnconditionaly: Bool?

    func protectedSend(_ string: String, connectUnconditionaly: Bool, completion: @escaping (Error?) -> Void) {
        lastConnectUnconditionaly = connectUnconditionaly
        send(string, completion: completion)
    }
    
    // Keep the old signature for backward compatibility
    func protectedSend(_ string: String, completion: @escaping (Error?) -> Void) {
        protectedSend(string, connectUnconditionaly: false, completion: completion)
    }

    func protectedSend(_ string: String) async throws {
        try await protectedSend(string, connectUnconditionaly: false)
    }

    func protectedSend(_ string: String, connectUnconditionaly: Bool) async throws {
        lastConnectUnconditionaly = connectUnconditionaly
        try await send(string)
    }

    func connect() {
        socketConnectionStatusPublisherSubject.send(.connected)
    }

    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) {
        socketConnectionStatusPublisherSubject.send(.disconnected)
    }

    func send(_ string: String, completion: @escaping (Error?) -> Void) {
        sent = true
        lastMessage = string

        usleep(20)
        if let data = string.data(using: .utf8),
           let request = try? JSONDecoder().decode(RPCRequest.self, from: data) {
            // Simulate the response
            let response = RPCResponse(matchingRequest: request, result: (AnyCodable(true)))
            // Trigger the onMessage with the response to simulate an instant acknowledgment
            if let jsonResponse = try? response.asJSONEncodedString() {
                self.onMessage?(jsonResponse)
            }
        }
    }
    func send(_ string: String) async throws {
        send(string, completion: { _ in })
    }
}

extension DispatcherMock {

    func getLastRequestSent() -> RPCRequest {
        let data = lastMessage.data(using: .utf8)!
        return try! JSONDecoder().decode(RPCRequest.self, from: data)
    }
}
