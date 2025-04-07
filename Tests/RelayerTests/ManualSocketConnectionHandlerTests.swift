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
    
    func testHandleConnectWithSubscriptions() {
        subscriptionsTracker.isSubscribedReturnValue = true
        
        // Create an expectation for the connection
        let connectionExpectation = XCTestExpectation(description: "Socket should connect")
        
        // Set up the mock to fulfill the expectation when connect is called
        socket.onConnect = {
            connectionExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        
        // Wait for the connection to complete
        wait(for: [connectionExpectation], timeout: 1.0)
        
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
        await fulfillment(of: [connectExpectation], timeout: 1.0)
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
    
    // MARK: - Reconnection Tests
    
    func testReconnectsOnDisconnection() async {
        subscriptionsTracker.isSubscribedReturnValue = true
        
        // Initial connection expectation
        let connectExpectation = XCTestExpectation(description: "Socket should connect initially")
        socket.onConnect = {
            connectExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        await fulfillment(of: [connectExpectation], timeout: 1.0)
        XCTAssertTrue(socket.isConnected)
        
        // Then simulate the status change for the handler to observe
        socketStatusProvider.simulateConnectionStatus(.disconnected)
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds

        XCTAssertTrue(socket.isConnected, "Socket should have reconnected")
    }

    
    func testStopsReconnectingOnManualDisconnect() async {
        subscriptionsTracker.isSubscribedReturnValue = true
        
        // Initial connection
        let connectExpectation = XCTestExpectation(description: "Socket should connect initially")
        socket.onConnect = {
            connectExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        await fulfillment(of: [connectExpectation], timeout: 1.0)
        XCTAssertTrue(socket.isConnected)
        
        // Trigger automatic reconnection flow
        socket.disconnect()
        socketStatusProvider.simulateConnectionStatus(.disconnected)
        
        // Wait for the reconnection to happen
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        
        // Socket should have reconnected automatically
        XCTAssertTrue(socket.isConnected, "Socket should have reconnected automatically")
        
        // Now manually disconnect
        try? sut.handleDisconnect(closeCode: .normalClosure)
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        XCTAssertFalse(socket.isConnected, "Socket should be disconnected after manual disconnect")
        
        // Try to trigger automatic reconnection again
        socketStatusProvider.simulateConnectionStatus(.disconnected)
        
        // Wait to ensure no reconnection happens
        try? await Task.sleep(nanoseconds: 200_000_000) // Wait 0.2 seconds
        
        // Socket should remain disconnected after manual disconnect
        XCTAssertFalse(socket.isConnected, "Socket should remain disconnected after manual disconnect")
    }
    
    // MARK: - Protocol Compliance Tests
    
    func testHandleInternalConnectDoesNothing() async throws {
        try await sut.handleInternalConnect()
        XCTAssertFalse(socket.isConnected)
    }
    
    func testHandleDisconnectionDoesNothing() async {
        await sut.handleDisconnection()
        XCTAssertFalse(socket.isConnected)
    }
}
