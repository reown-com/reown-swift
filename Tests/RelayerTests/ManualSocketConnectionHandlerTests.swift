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
    
    func testHandleConnectWithNoSubscriptions() {
        subscriptionsTracker.isSubscribedReturnValue = false
        try? sut.handleConnect()
        XCTAssertFalse(socket.isConnected)
    }
    
    func testHandleConnectWithSubscriptions() {
        subscriptionsTracker.isSubscribedReturnValue = true
        try? sut.handleConnect()
        XCTAssertTrue(socket.isConnected)
    }
    
    func testHandleConnectIgnoresWhenAlreadyConnecting() {
        subscriptionsTracker.isSubscribedReturnValue = true
        socket.blockConnection = true
        try? sut.handleConnect()
        try? sut.handleConnect()
        XCTAssertEqual(logger.debugCallCount, 2) // One for "Starting connection process" and one for "Already connecting"
    }
    
    // MARK: - Disconnection Tests
    
    func testHandleDisconnect() {
        subscriptionsTracker.isSubscribedReturnValue = true
        try? sut.handleConnect()
        XCTAssertTrue(socket.isConnected)
        try? sut.handleDisconnect(closeCode: .normalClosure)
        XCTAssertFalse(socket.isConnected)
    }
    
    // MARK: - Reconnection Tests
    
    func testReconnectsOnDisconnection() async {
        subscriptionsTracker.isSubscribedReturnValue = true
        try? sut.handleConnect()
        XCTAssertTrue(socket.isConnected)
        
        socketStatusProvider.simulateConnectionStatus(.disconnected)
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        
        XCTAssertTrue(socket.isConnected) // Should have reconnected
    }
    
    func testStopsReconnectingAfterMaxAttempts() async async {
        subscriptionsTracker.isSubscribedReturnValue = true
        socket.blockConnection = true
        try? sut.handleConnect()
        
        // Simulate disconnections up to max attempts
        for _ in 0..<3 {
            socketStatusProvider.simulateConnectionStatus(.disconnected)
            try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        }
        
        // One more disconnection should trigger periodic reconnection
        socketStatusProvider.simulateConnectionStatus(.disconnected)
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        
        XCTAssertFalse(socket.isConnected)
    }
    
    func testStopsReconnectingOnManualDisconnect() async {
        subscriptionsTracker.isSubscribedReturnValue = true
        try? sut.handleConnect()
        XCTAssertTrue(socket.isConnected)
        
        socketStatusProvider.simulateConnectionStatus(.disconnected)
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        
        try? sut.handleDisconnect(closeCode: .normalClosure)
        XCTAssertFalse(socket.isConnected)
        
        // Simulate another disconnection
        socketStatusProvider.simulateConnectionStatus(.disconnected)
        try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
        
        XCTAssertFalse(socket.isConnected) // Should not reconnect after manual disconnect
    }
    
    // MARK: - Token Refresh Tests
    
    func testRefreshesTokenOnConnect() {
        subscriptionsTracker.isSubscribedReturnValue = true
        let testToken = "test_token"
        socket.request.allHTTPHeaderFields = ["Authorization": "Bearer \(testToken)"]
        
        try? sut.handleConnect()
        
        // Verify that the token was refreshed
        XCTAssertNotEqual(socket.request.allHTTPHeaderFields?["Authorization"], "Bearer \(testToken)")
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
