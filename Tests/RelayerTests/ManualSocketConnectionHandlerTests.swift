import Foundation
import XCTest
@testable import WalletConnectRelay

final class ManualSocketConnectionHandlerTests: XCTestCase {
    var sut: ManualSocketConnectionHandler!
    var socket: WebSocketMock!
    var subscriptionsTracker: SubscriptionsTrackerMock!
    var clientIdAuthenticator: ClientIdAuthenticator!
    var socketStatusProvider: SocketStatusProviderMock!
    var logger: ConsoleLoggerMock!
    
    override func setUp() {
        socket = WebSocketMock()
        subscriptionsTracker = SubscriptionsTrackerMock()
        logger = ConsoleLoggerMock()
        
        let defaults = RuntimeKeyValueStorage()
        let keychainStorageMock = DispatcherKeychainStorageMock()
        let clientIdStorage = ClientIdStorage(defaults: defaults, keychain: keychainStorageMock, logger: logger)
        clientIdAuthenticator = ClientIdAuthenticator(clientIdStorage: clientIdStorage, logger: logger)
        
        socketStatusProvider = SocketStatusProviderMock()
        
        sut = ManualSocketConnectionHandler(
            socket: socket,
            logger: logger,
            subscriptionsTracker: subscriptionsTracker,
            clientIdAuthenticator: clientIdAuthenticator,
            socketStatusProvider: socketStatusProvider
        )
    }
    
    // MARK: - Connection Tests
    
    func testHandleConnectWithNoSubscriptions() async {
        subscriptionsTracker.isSubscribedReturnValue = false
        
        // Set up a potential connection expectation
        let potentialConnectExpectation = XCTestExpectation(description: "Socket might connect")
        potentialConnectExpectation.isInverted = true // We don't expect it to happen
        
        socket.onConnect = {
            potentialConnectExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        
        // Give it some time to potentially connect (should not happen)
        await fulfillment(of: [potentialConnectExpectation], timeout: 0.05)
        
        // Verify it did not connect
        XCTAssertFalse(socket.isConnected, "Socket should not connect when there are no subscriptions")
    }
    
    func testHandleConnectWithSubscriptions() async {
        subscriptionsTracker.isSubscribedReturnValue = true
        
        // Create an expectation for the connection
        let connectionExpectation = XCTestExpectation(description: "Socket should connect")
        
        // Set up the mock to fulfill the expectation when connect is called
        socket.onConnect = {
            connectionExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        
        // Wait for the connection to complete
        await fulfillment(of: [connectionExpectation], timeout: 0.2)
        
        // Now assert that the socket is connected
        XCTAssertTrue(socket.isConnected)
    }
    
    // MARK: - Disconnection Tests
    
    func testHandleDisconnect() async {
        subscriptionsTracker.isSubscribedReturnValue = true
        
        // Connection expectation
        let connectExpectation = XCTestExpectation(description: "Socket should connect")
        socket.onConnect = {
            connectExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        await fulfillment(of: [connectExpectation], timeout: 0.2)
        XCTAssertTrue(socket.isConnected)
        
        // Disconnection expectation
        let disconnectExpectation = XCTestExpectation(description: "Socket should disconnect")
        socket.onDisconnect = { _ in
            disconnectExpectation.fulfill()
        }
        
        try? sut.handleDisconnect(closeCode: .normalClosure)
        await fulfillment(of: [disconnectExpectation], timeout: 1.0)
        XCTAssertFalse(socket.isConnected)
    }
    
    func testSocketDoesNotReconnectOnDisconnection() async {
        subscriptionsTracker.isSubscribedReturnValue = true
        
        // Initial connection
        let connectExpectation = XCTestExpectation(description: "Socket should connect initially")
        socket.onConnect = {
            connectExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        await fulfillment(of: [connectExpectation], timeout: 1.0)
        XCTAssertTrue(socket.isConnected)
        
        // Disconnect
        socket.disconnect()
        socketStatusProvider.simulateConnectionStatus(.disconnected)
        
        // Give time for any potential reconnection attempts (which should not happen)
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        
        // Verify the socket stays disconnected
        XCTAssertFalse(socket.isConnected, "Socket should remain disconnected because ManualSocketConnectionHandler does not automatically reconnect")
    }
    
    // MARK: - Protocol Compliance Tests
    
    func testHandleInternalConnectDoesNothing() async throws {
        try await sut.handleInternalConnect()
        XCTAssertFalse(socket.isConnected)
    }
    
    func testHandleInternalConnectConnectsWhenSubscribed() async throws {
        // Set subscriptions to true
        subscriptionsTracker.isSubscribedReturnValue = true
        
        // Create an expectation for the connection
        let connectionExpectation = XCTestExpectation(description: "Socket should connect via handleInternalConnect")
        
        // Set up the mock to fulfill the expectation when connect is called
        socket.onConnect = {
            connectionExpectation.fulfill()
        }
        
        // Call handleInternalConnect which should now connect the socket
        try await sut.handleInternalConnect()
        
        // Wait for the connection to complete
        await fulfillment(of: [connectionExpectation], timeout: 0.2)
        
        // Assert that the socket is connected
        XCTAssertTrue(socket.isConnected, "Socket should be connected after handleInternalConnect call")
    }
    
    func testHandleInternalConnectDoesNotConnectWithoutSubscriptions() async throws {
        // Set subscriptions to false
        subscriptionsTracker.isSubscribedReturnValue = false
        
        // Create an expectation that should not be fulfilled (inverted)
        let noConnectionExpectation = XCTestExpectation(description: "Socket should not connect without subscriptions")
        noConnectionExpectation.isInverted = true
        
        // Set up the mock to fulfill the expectation if connect is called (which it shouldn't be)
        socket.onConnect = {
            noConnectionExpectation.fulfill()
        }
        
        // Call handleInternalConnect
        try await sut.handleInternalConnect()
        
        // Wait to ensure connect is not called
        await fulfillment(of: [noConnectionExpectation], timeout: 0.1)
        
        // Assert that the socket is not connected
        XCTAssertFalse(socket.isConnected, "Socket should not connect when there are no subscriptions")
    }
}
