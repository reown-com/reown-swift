import Foundation
import XCTest
import Combine
@testable import WalletConnectRelay
import TestingUtils
import Combine

class DispatcherKeychainStorageMock: KeychainStorageProtocol {
    func add<T>(_ item: T, forKey key: String) throws where T : WalletConnectKMS.GenericPasswordConvertible {}
    func read<T>(key: String) throws -> T where T : WalletConnectKMS.GenericPasswordConvertible {
        return try T(rawRepresentation: Data())
    }
    func delete(key: String) throws {}
    func deleteAll() throws {}
}

final class DispatcherTests: XCTestCase {
    var publishers = Set<AnyCancellable>()
    var sut: Dispatcher!
    var webSocket: WebSocketMock!
    var networkMonitor: NetworkMonitoringMock!
    var socketStatusProviderMock: SocketStatusProviderMock!

    override func setUp() {
        webSocket = WebSocketMock()
        let webSocketFactory = WebSocketFactoryMock(webSocket: webSocket)
        networkMonitor = NetworkMonitoringMock()
        let defaults = RuntimeKeyValueStorage()
        let logger = ConsoleLoggerMock()
        let networkMonitor = NetworkMonitoringMock()
        let keychainStorageMock = DispatcherKeychainStorageMock()
        let clientIdStorage = ClientIdStorage(defaults: defaults, keychain: keychainStorageMock, logger: logger)
        let relayUrlFactory = RelayUrlFactory(
            relayHost: "relay.walletconnect.com",
            projectId: "1012db890cf3cfb0c1cdc929add657ba"
        )
        let socketAuthenticator = ClientIdAuthenticator(
            clientIdStorage: clientIdStorage,
            logger: logger
        )
        let socketStatusProvider = SocketStatusProvider(socket: webSocket, logger: logger)
        let topicsTracker = TopicsTrackerMock()
        topicsTracker.isTrackingAnyTopicsReturnValue = true

        let socketConnectionHandler = ManualSocketConnectionHandler(socket: webSocket, logger: logger, topicsTracker: topicsTracker, clientIdAuthenticator: socketAuthenticator, socketStatusProvider: socketStatusProvider)
        socketStatusProviderMock = SocketStatusProviderMock()
        sut = Dispatcher(
            socketFactory: webSocketFactory,
            relayUrlFactory: relayUrlFactory, 
            networkMonitor: networkMonitor,
            socket: webSocket,
            logger: ConsoleLoggerMock(),
            socketConnectionHandler: socketConnectionHandler,
            socketStatusProvider: socketStatusProviderMock
        )
    }

    func testSendWhileConnected() async {
        // Create an expectation for the connection
        let connectExpectation = XCTestExpectation(description: "Socket should connect")
        
        // Set up the callback to fulfill the expectation when connected
        webSocket.onConnect = {
            connectExpectation.fulfill()
        }
        
        // Initiate connection
        try! sut.connect()
        
        // Wait for connection to complete
        await fulfillment(of: [connectExpectation], timeout: 0.5)
        
        // Verify socket is connected
        XCTAssertTrue(webSocket.isConnected, "Socket should be connected before sending")
        
        // Send the message
        sut.protectedSend("1") {_ in}
        
        // Verify the message was sent
        XCTAssertEqual(webSocket.sendCallCount, 1)
    }

    func testOnMessage() {
        let expectation = expectation(description: "on message")
        sut.onMessage = { message in
            XCTAssertNotNil(message)
            expectation.fulfill()
        }
        webSocket.onText?("message")
        waitForExpectations(timeout: 0.001)
    }

    func testOnConnect() {
        let expectation = expectation(description: "on connect")
        sut.socketConnectionStatusPublisher.sink { status in
            guard status == .connected else { return }
            expectation.fulfill()
        }.store(in: &publishers)
        socketStatusProviderMock.simulateConnectionStatus(.connected)
        waitForExpectations(timeout: 0.001)
    }

    func testOnDisconnect() throws {
        let expectation = expectation(description: "on disconnect")
        try sut.connect()
        sut.socketConnectionStatusPublisher.sink { status in
            guard status == .disconnected else { return }
            expectation.fulfill()
        }.store(in: &publishers)
        socketStatusProviderMock.simulateConnectionStatus(.disconnected)
        waitForExpectations(timeout: 0.001)
    }

    func testProtectedSendWithoutConnectUnconditionaly() async throws {
        // Ensure socket is not connected initially
        webSocket.isConnected = false
        
        // Create an expectation for the connection attempt
        let connectionAttemptExpectation = XCTestExpectation(description: "Connection attempt should be rejected")
        
        // Send message with connectUnconditionaly = false and expect error
        do {
            try await sut.protectedSend("test message", connectUnconditionaly: false)
            XCTFail("protectedSend should throw when connectUnconditionaly is false and no topics are tracked")
        } catch ManualSocketConnectionHandler.Errors.internalConnectionRejected {
            // This is the expected error
            connectionAttemptExpectation.fulfill()
        }
        
        // Wait for the expectation to be fulfilled
        await fulfillment(of: [connectionAttemptExpectation], timeout: 1.0)
        
        // Verify socket remains disconnected
        XCTAssertFalse(webSocket.isConnected, "Socket should not connect when connectUnconditionaly is false and no topics are tracked")
        XCTAssertEqual(webSocket.sendCallCount, 0, "No message should be sent")
    }

    func testProtectedSendConnectsAndSendsSuccessfullyBeforeTimeout() async throws {
        // Configure a short timeout for the test
        sut.connectionTimeoutDuration = 0.2 // 200ms
        
        // Ensure socket starts disconnected
        webSocket.isConnected = false

        let sendExpectation = XCTestExpectation(description: "protectedSend completes successfully")


        // Simulate connection success shortly after the call
        Task {
            try await Task.sleep(nanoseconds: 10_000_000) // 100ms (before timeout)
            socketStatusProviderMock.simulateConnectionStatus(.connected)
        }

        // Call protectedSend (using the async version for cleaner testing)
        do {
            try await sut.protectedSend("message-before-timeout", connectUnconditionaly: true)
            sendExpectation.fulfill()
        } catch {
            XCTFail("protectedSend should succeed but failed with error: \(error)")
        }

        // Wait for expectations
        await fulfillment(of: [sendExpectation], timeout: 0.5)

        // Verify message was sent
        XCTAssertEqual(webSocket.sendCallCount, 1, "Message should be sent after successful connection")
    }

    func testProtectedSendTimesOutAndFails() async throws {
        // Configure a very short timeout
        sut.connectionTimeoutDuration = 0.1 // 100ms
        
        // Ensure socket starts disconnected
        webSocket.isConnected = false

        let errorExpectation = XCTestExpectation(description: "protectedSend fails with timeout error")

        // Call protectedSend and expect a timeout error
        do {
            try await sut.protectedSend("message-that-will-timeout", connectUnconditionaly: true)
            XCTFail("protectedSend should have thrown a timeout error")
        } catch NetworkError.connectionFailed {
            // Expected error
            errorExpectation.fulfill()
        } catch {
            XCTFail("protectedSend threw an unexpected error: \(error)")
        }

        // Wait for the expected error
        await fulfillment(of: [errorExpectation], timeout: 0.5)

        // Verify no message was sent
        XCTAssertEqual(webSocket.sendCallCount, 0, "No message should be sent after timeout")
    }
}
