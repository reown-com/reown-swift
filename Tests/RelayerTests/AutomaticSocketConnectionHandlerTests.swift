import Foundation
import XCTest
@testable import WalletConnectRelay

final class AutomaticSocketConnectionHandlerTests: XCTestCase {
    var sut: AutomaticSocketConnectionHandler!
    var webSocketSession: WebSocketMock!
    var networkMonitor: NetworkMonitoringMock!
    var appStateObserver: AppStateObserverMock!
    var backgroundTaskRegistrar: BackgroundTaskRegistrarMock!
    var subscriptionsTracker: SubscriptionsTrackerMock!
    var socketStatusProviderMock: SocketStatusProviderMock!

    override func setUp() {
        webSocketSession = WebSocketMock()
        networkMonitor = NetworkMonitoringMock()
        appStateObserver = AppStateObserverMock()

        let logger = ConsoleLogger(prefix: "", loggingLevel: .debug)

        backgroundTaskRegistrar = BackgroundTaskRegistrarMock()
        subscriptionsTracker = SubscriptionsTrackerMock()

        socketStatusProviderMock = SocketStatusProviderMock()

        sut = AutomaticSocketConnectionHandler(
            socket: webSocketSession,
            networkMonitor: networkMonitor,
            appStateObserver: appStateObserver,
            backgroundTaskRegistrar: backgroundTaskRegistrar,
            subscriptionsTracker: subscriptionsTracker,
            logger: logger,
            socketStatusProvider: socketStatusProviderMock,
            clientIdAuthenticator: ClientIdAuthenticator(clientIdStorage: ClientIdStorageMock(), logger: ConsoleLoggerMock())
        )
        sut.periodicReconnectionInterval = 0.1 // 100 milliseconds
    }

    func testConnectsOnConnectionSatisfied() {
        // Ensure the socket is disconnected
        webSocketSession.isConnected = false
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate active subscriptions
        XCTAssertFalse(webSocketSession.isConnected)

        let expectation = XCTestExpectation(description: "WebSocket should connect when network becomes connected")

        // Assign onConnect closure to fulfill the expectation and set isConnected
        webSocketSession.onConnect = {
            expectation.fulfill()
        }

        // Simulate network connection becoming connected
        networkMonitor.networkConnectionStatusPublisherSubject.send(.connected)

        wait(for: [expectation], timeout: 10)
    }

    func testHandleConnectThrows() {
        XCTAssertThrowsError(try sut.handleConnect())
    }

    func testHandleDisconnectThrows() {
        XCTAssertThrowsError(try sut.handleDisconnect(closeCode: .normalClosure))
    }

    func testReconnectsOnEnterForeground() {
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate that there are active subscriptions
        webSocketSession.isConnected = false

        let expectation = XCTestExpectation(description: "WebSocket should connect on entering foreground")

        // Modify the webSocketSession mock to call this closure when connect() is called
        webSocketSession.onConnect = {
            expectation.fulfill()
        }

        appStateObserver.onWillEnterForeground?()

        wait(for: [expectation], timeout: 14.0)
        XCTAssertTrue(webSocketSession.isConnected)
    }

    func testReconnectsOnEnterForegroundWhenNoSubscriptions() {
        subscriptionsTracker.isSubscribedReturnValue = false // Simulate no active subscriptions
        webSocketSession.isConnected = false
        appStateObserver.onWillEnterForeground?()
        XCTAssertFalse(webSocketSession.isConnected) // The connection should not be re-established
    }

    func testRegisterTaskOnEnterBackground() {
        XCTAssertNil(backgroundTaskRegistrar.completion)
        appStateObserver.onWillEnterBackground?()
        XCTAssertNotNil(backgroundTaskRegistrar.completion)
    }

    func testDisconnectOnEndBackgroundTask() {
        appStateObserver.onWillEnterBackground?()
        webSocketSession.connect()
        XCTAssertTrue(webSocketSession.isConnected)
        backgroundTaskRegistrar.completion!()
        XCTAssertFalse(webSocketSession.isConnected)
    }

    func testReconnectOnDisconnectForeground() async {
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate that there are active subscriptions
        webSocketSession.isConnected = false
        appStateObserver.currentState = .foreground

        let expectation = XCTestExpectation(description: "WebSocket should reconnect on disconnection in foreground")

        // Modify the webSocketSession mock to call this closure when connect() is called
        webSocketSession.onConnect = {
            expectation.fulfill()
        }

        await sut.handleDisconnection()

        await fulfillment(of: [expectation], timeout: 15.0)
    }

    func testNotReconnectOnDisconnectForegroundWhenNoSubscriptions() async {
        subscriptionsTracker.isSubscribedReturnValue = false // Simulate no active subscriptions
        webSocketSession.isConnected = true
        appStateObserver.currentState = .foreground
        XCTAssertTrue(webSocketSession.isConnected)
        webSocketSession.disconnect()
        await sut.handleDisconnection()
        XCTAssertFalse(webSocketSession.isConnected) // The connection should not be re-established
    }

    func testReconnectOnDisconnectBackground() async {
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate that there are active subscriptions
        webSocketSession.isConnected = true
        appStateObserver.currentState = .background
        XCTAssertTrue(webSocketSession.isConnected)
        webSocketSession.disconnect()
        await sut.handleDisconnection()
        XCTAssertFalse(webSocketSession.isConnected)
    }

    func testNotReconnectOnDisconnectBackgroundWhenNoSubscriptions() async {
        subscriptionsTracker.isSubscribedReturnValue = false // Simulate no active subscriptions
        webSocketSession.isConnected = true
        appStateObserver.currentState = .background
        XCTAssertTrue(webSocketSession.isConnected)
        webSocketSession.disconnect()
        await sut.handleDisconnection()
        XCTAssertFalse(webSocketSession.isConnected) // The connection should not be re-established
    }

    func testReconnectIfNeededWhenSubscribed() {
        // Simulate that there are active subscriptions
        subscriptionsTracker.isSubscribedReturnValue = true
        appStateObserver.currentState = .foreground // Ensure app is in the foreground

        // Ensure socket is disconnected initially
        webSocketSession.isConnected = false

        let expectation = XCTestExpectation(description: "WebSocket should connect when reconnectIfNeeded is called")

        // Modify the webSocketSession mock to call this closure when connect() is called
        webSocketSession.onConnect = {
            expectation.fulfill()
        }

        // Trigger reconnect logic
        sut.reconnectIfNeeded()

        wait(for: [expectation], timeout: 15.0) // Increased timeout
    }

    func testReconnectIfNeededWhenNotSubscribed() {
        // Simulate that there are no active subscriptions
        subscriptionsTracker.isSubscribedReturnValue = false

        // Ensure socket is disconnected initially
        webSocketSession.isConnected = false
        XCTAssertFalse(webSocketSession.isConnected)

        // Trigger reconnect logic
        sut.reconnectIfNeeded()

        // Expect the socket to remain disconnected since there are no subscriptions
        XCTAssertFalse(webSocketSession.isConnected)
    }

    func testReconnectsOnEnterForegroundWhenSubscribed() async {
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate that there are active subscriptions
        webSocketSession.isConnected = false

        let expectation = XCTestExpectation(description: "WebSocket should reconnect when entering foreground and subscriptions exist")

        // Set up the mock to fulfill expectation when connect is called
        webSocketSession.onConnect = {
            expectation.fulfill()
        }

        // Simulate entering foreground
        appStateObserver.onWillEnterForeground?()

        await fulfillment(of: [expectation], timeout: 15.0)
    }

//    func testSwitchesToPeriodicReconnectionAfterMaxImmediateAttempts() async {
//        subscriptionsTracker.isSubscribedReturnValue = true // Ensure subscriptions exist to allow reconnection
//        sut.periodicReconnectionInterval = 3 // Set shorter interval for testing
//        webSocketSession.blockConnection = true
//        sut.connect() // Start connection process
//
//        // Simulate immediate reconnection attempts
//        Task(priority: .high) {
//            try? await Task.sleep(nanoseconds: 100_000_000) // 200ms
//            for _ in 0..<sut.maxImmediateAttempts {
//                print("Simulating disconnection")
//                socketStatusProviderMock.simulateConnectionStatus(.disconnected)
//
//                // Wait to allow the handler to process each disconnection
//                try? await Task.sleep(nanoseconds: 400_000_000) // 200ms
//            }
//            socketStatusProviderMock.simulateConnectionStatus(.disconnected)
//        }
//
//        // Simulate one more disconnection to trigger switching to periodic reconnection
//
//        // Allow time for the reconnection logic to switch to periodic
//        try? await Task.sleep(nanoseconds: 3_200_000_000) // 500ms
//
//        // Verify that reconnectionAttempts is set to maxImmediateAttempts and timer is started
//        sut.syncQueue.sync {
//            XCTAssertEqual(sut.reconnectionAttempts, sut.maxImmediateAttempts)
//            XCTAssertNotNil(sut.reconnectionTimer)
//        }
//    }

    func testPeriodicReconnectionStopsAfterSuccessfulConnection() async {
        sut.periodicReconnectionInterval = 0.1 // Set shorter interval for testing
        sut.connect() // Start connection process

        // Simulate immediate reconnection attempts
        for _ in 0...sut.maxImmediateAttempts {
            socketStatusProviderMock.simulateConnectionStatus(.disconnected)
            try? await Task.sleep(nanoseconds: 300_000_000) // 100ms
        }
        try? await Task.sleep(nanoseconds: 300_000_000) // 100ms

        // Now simulate the connection being successful
        socketStatusProviderMock.simulateConnectionStatus(.connected)
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Periodic reconnection timer should stop
        sut.syncQueue.sync {
            XCTAssertNil(sut.reconnectionTimer)
            XCTAssertEqual(sut.reconnectionAttempts, 0) // Attempts should be reset
        }
    }

    func testHandleInternalConnectThrowsAfterThreeDisconnections() async throws {
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate active subscriptions
        appStateObserver.currentState = .foreground // Ensure app is in foreground
        webSocketSession.blockConnection = true
        webSocketSession.isConnected = false

        // Start a task to call handleInternalConnect and await its result
        let handleConnectTask = Task {
            do {
                try await sut.handleInternalConnect()
                XCTFail("Expected handleInternalConnect to throw NetworkError.connectionFailed after three disconnections")
            } catch NetworkError.connectionFailed {
                // Expected behavior
            } catch {
                XCTFail("Expected NetworkError.connectionFailed, but got \(error)")
            }
        }

        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
            // Simulate three disconnections
            for _ in 0..<sut.maxImmediateAttempts {
                socketStatusProviderMock.simulateConnectionStatus(.disconnected)
                try await Task.sleep(nanoseconds: 100_000_000) // Wait 0.001 seconds

            }

        }

        // Wait for the task to complete
        await handleConnectTask.value
    }

    func testHandleInternalConnectSuccessWithNoFailures() async throws {
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate active subscriptions
        appStateObserver.currentState = .foreground // Ensure app is in foreground

        // Start a task to call handleInternalConnect and await its result
        let handleConnectTask = Task {
            do {
                try await sut.handleInternalConnect()
                // Success expected, do nothing
            } catch {
                XCTFail("Expected handleInternalConnect to succeed, but it threw: \(error)")
            }
        }

        // Allow handleInternalConnect() to start observing

        Task {
            try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.1 seconds
            socketStatusProviderMock.simulateConnectionStatus(.connected)
        }
        // Wait for the task to complete
        await handleConnectTask.value

        // Verify that the state is as expected after a successful connection
        sut.syncQueue.sync {
            print("isConnecting: \(sut.isConnecting)")
            print("reconnectionTimer: \(sut.reconnectionTimer)")
            print("reconnectionAttempts: \(sut.reconnectionAttempts)")
            XCTAssertFalse(sut.isConnecting)
            XCTAssertNil(sut.reconnectionTimer)
            XCTAssertEqual(sut.reconnectionAttempts, 0)
        }
    }

    func testHandleInternalConnectSuccessAfterFailures() async throws {
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate active subscriptions
        appStateObserver.currentState = .foreground // Ensure app is in foreground

        // Start a task to call handleInternalConnect and await its result
        let handleConnectTask = Task {
            do {
                try await sut.handleInternalConnect()
                // Success expected, do nothing
            } catch {
                XCTFail("Expected handleInternalConnect to succeed after disconnections followed by a connection, but it threw: \(error)")
            }
        }

        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1 seconds
            // Simulate two disconnections
            for _ in 0..<2 {
                socketStatusProviderMock.simulateConnectionStatus(.disconnected)
                try await Task.sleep(nanoseconds: 100_000_000) // Wait 0.001 seconds
            }

            // Simulate a successful connection
            socketStatusProviderMock.simulateConnectionStatus(.connected)
        }

        // Wait for the task to complete
        await handleConnectTask.value

        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 0.001 seconds
        // Verify that the state is as expected after a successful connection

        sut.syncQueue.sync {
            print("isConnecting: \(sut.isConnecting)")
            print("reconnectionTimer: \(sut.reconnectionTimer)")
            print("reconnectionAttempts: \(sut.reconnectionAttempts)")
            XCTAssertFalse(sut.isConnecting)
            XCTAssertNil(sut.reconnectionTimer)
            XCTAssertEqual(sut.reconnectionAttempts, 0) // Attempts should reset after success
        }
    }

    func testHandleInternalConnectTimeout() async throws {
        subscriptionsTracker.isSubscribedReturnValue = true // Simulate active subscriptions
        appStateObserver.currentState = .foreground // Ensure app is in foreground
        webSocketSession.blockConnection = true

        // Set a short timeout for testing purposes
        sut.requestTimeout = 0.01

        // Start a task to call handleInternalConnect and await its result
        let handleConnectTask = Task {
            do {
                try await sut.handleInternalConnect()
                XCTFail("Expected handleInternalConnect to throw NetworkError.connectionFailed due to timeout")
            } catch NetworkError.connectionFailed {
                // Expected behavior
                XCTAssertEqual(sut.reconnectionAttempts, 0) // No reconnection attempts should be recorded for timeout
            } catch {
                XCTFail("Expected NetworkError.connectionFailed due to timeout, but got \(error)")
            }
        }


        // No connection simulation to allow timeout to trigger

        // Wait for the task to complete
        await handleConnectTask.value
    }
}
