import Foundation
import XCTest
@testable import WalletConnectRelay

final class ManualSocketConnectionHandlerTests: XCTestCase {
    var sut: ManualSocketConnectionHandler!
    var socket: WebSocketMock!
    var topicsTracker: TopicsTrackerMock!
    var clientIdAuthenticator: ClientIdAuthenticator!
    var socketStatusProvider: SocketStatusProviderMock!
    var logger: ConsoleLoggerMock!
    
    override func setUp() {
        socket = WebSocketMock()
        topicsTracker = TopicsTrackerMock()
        logger = ConsoleLoggerMock()
        
        let defaults = RuntimeKeyValueStorage()
        let keychainStorageMock = DispatcherKeychainStorageMock()
        let clientIdStorage = ClientIdStorage(defaults: defaults, keychain: keychainStorageMock, logger: logger)
        clientIdAuthenticator = ClientIdAuthenticator(clientIdStorage: clientIdStorage, logger: logger)
        
        socketStatusProvider = SocketStatusProviderMock()
        
        sut = ManualSocketConnectionHandler(
            socket: socket,
            logger: logger,
            topicsTracker: topicsTracker,
            clientIdAuthenticator: clientIdAuthenticator,
            socketStatusProvider: socketStatusProvider
        )
    }
    
    // MARK: - Connection Tests
    
    func testHandleConnectWithNoTopics() async {
        topicsTracker.isTrackingAnyTopicsReturnValue = false
        
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
        XCTAssertFalse(socket.isConnected, "Socket should not connect when there are no topics")
    }
    
    func testHandleConnectWithTopics() async {
        topicsTracker.isTrackingAnyTopicsReturnValue = true
        
        // Create an expectation for the connection
        let connectionExpectation = XCTestExpectation(description: "Socket should connect")
        
        // Set up the mock to fulfill the expectation when connect is called
        socket.onConnect = {
            connectionExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        
        // Wait for the connection to complete
        await fulfillment(of: [connectionExpectation], timeout: 0.3)
        
        // Now assert that the socket is connected
        XCTAssertTrue(socket.isConnected)
    }
    
    // MARK: - Disconnection Tests
    
    func testHandleDisconnect() async {
        topicsTracker.isTrackingAnyTopicsReturnValue = true
        
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
        topicsTracker.isTrackingAnyTopicsReturnValue = true
        
        // Initial connection
        let connectExpectation = XCTestExpectation(description: "Socket should connect initially")
        socket.onConnect = {
            connectExpectation.fulfill()
        }
        
        try? sut.handleConnect()
        await fulfillment(of: [connectExpectation], timeout: 0.2)
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
    
    func testHandleInternalConnectRejectsSubscriptionEvents() async throws {
        // Should throw an error when unconditionaly is false (subscription event)
        var errorThrown = false
        do {
            try await sut.handleInternalConnect(unconditionally: false)
        } catch ManualSocketConnectionHandler.Errors.internalConnectionRejected {
            // Expected specific error
            errorThrown = true
        } catch {
            XCTFail("Should throw ManualSocketConnectionHandler.Errors.subscriptionConnectionRejected but threw \(error)")
        }
        
        XCTAssertTrue(errorThrown, "handleInternalConnect should throw subscriptionConnectionRejected when unconditionaly is false")
        XCTAssertFalse(socket.isConnected)
    }
    
    // MARK: - InternalConnect Tests
    
    func testHandleInternalConnectWithUnconditionalTrue() async throws {
        // Configure a short timeout for faster testing
        sut.connectionTimeout = 1.0
        
        // Set up connection expectation
        let connectionExpectation = XCTestExpectation(description: "Socket should connect when unconditionaly is true")
        
        // Set up the mock to fulfill expectation on connect
        socket.onConnect = {
            connectionExpectation.fulfill()
        }
        
        // Call with unconditionaly = true
        Task {
            try await sut.handleInternalConnect(unconditionally: true)
        }
        
        // Wait a brief moment for the connection attempt
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        
        // Simulate successful connection
        socketStatusProvider.simulateConnectionStatus(.connected)
        
        // Wait for the connection expectation to be fulfilled
        await fulfillment(of: [connectionExpectation], timeout: 1.5)
        
        // Verify socket was connected
        XCTAssertTrue(socket.isConnected, "Socket should connect when unconditionaly is true")
    }
    
    func testHandleInternalConnectWithUnconditionalFalse() async {
        // When unconditionaly is false, handleInternalConnect should throw an error
        var errorThrown = false
        
        do {
            try await sut.handleInternalConnect(unconditionally: false)
            XCTFail("handleInternalConnect should throw when unconditionally is false")
        } catch ManualSocketConnectionHandler.Errors.internalConnectionRejected {
            // This is the expected error
            errorThrown = true
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
        
        XCTAssertTrue(errorThrown, "Expected internalConnectionRejected error to be thrown")
        XCTAssertFalse(socket.isConnected, "Socket should not be connected")
    }
    
    func testHandleInternalConnectTimeout() async {
        // Set a very short timeout
        sut.connectionTimeout = 0.1 // 100ms
        
        // Create a socket mock that blocks connection attempts
        socket.blockConnection = true 
        
        // Attempt to connect with unconditionaly = true
        do {
            try await sut.handleInternalConnect(unconditionally: true)
            XCTFail("handleInternalConnect should timeout and throw")
        } catch NetworkError.connectionFailed {
            // This is the expected timeout error
            XCTAssertFalse(socket.isConnected, "Socket should remain disconnected after timeout")
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }
    
    func testHandleInternalConnectAlreadyConnected() async throws {
        // Set socket to already connected
        socket.isConnected = true
        
        // Call with unconditionaly = true
        try await sut.handleInternalConnect(unconditionally: true)
        
        // Verify no additional connect attempt was made
        XCTAssertEqual(socket.connectCallCount, 0, "Socket.connect() should not be called when already connected")
    }
    
    func testHandleInternalConnectAlreadyConnecting() async throws {
        // Set up the handler to be already in connecting state
        sut.isConnecting = true
        
        // Call with unconditionally = true
        try await sut.handleInternalConnect(unconditionally: true)
        
        // Verify no connect attempt was made
        XCTAssertEqual(socket.connectCallCount, 0, "Socket.connect() should not be called when already connecting")
    }
}
