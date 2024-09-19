import Foundation
import Combine
import XCTest
import WalletConnectUtils
import Starscream
@testable import WalletConnectRelay

private class RelayKeychainStorageMock: KeychainStorageProtocol {
    func add<T>(_ item: T, forKey key: String) throws where T : WalletConnectKMS.GenericPasswordConvertible {}
    func read<T>(key: String) throws -> T where T : WalletConnectKMS.GenericPasswordConvertible {
        return try T(rawRepresentation: Data())
    }
    func delete(key: String) throws {}
    func deleteAll() throws {}
}

class WebSocketFactoryMock: WebSocketFactory {
    private let webSocket: WebSocket
    
    init(webSocket: WebSocket) {
        self.webSocket = webSocket
    }
    
    func create(with url: URL) -> WebSocketConnecting {
        return webSocket
    }
}

final class RelayClientEndToEndTests: XCTestCase {

    private var publishers = Set<AnyCancellable>()
    private var relayA: RelayClient!
    private var relayB: RelayClient!

    func makeRelayClient(prefix: String) -> RelayClient {
        let keyValueStorage = RuntimeKeyValueStorage()
        let logger = ConsoleLogger(prefix: prefix, loggingLevel: .debug)
        let clientIdStorage = ClientIdStorage(defaults: keyValueStorage, keychain: KeychainStorageMock(), logger: logger)
        let socketAuthenticator = ClientIdAuthenticator(
            clientIdStorage: clientIdStorage
        )
        let urlFactory = RelayUrlFactory(
            relayHost: InputConfig.relayHost,
            projectId: InputConfig.projectId,
            socketAuthenticator: socketAuthenticator
        )
        let socket = WebSocket(url: urlFactory.create())
        let webSocketFactory = WebSocketFactoryMock(webSocket: socket)
        let networkMonitor = NetworkMonitor()

        let relayUrlFactory = RelayUrlFactory(
            relayHost: "relay.walletconnect.com",
            projectId: "1012db890cf3cfb0c1cdc929add657ba",
            socketAuthenticator: socketAuthenticator
        )

        let socketStatusProvider = SocketStatusProvider(socket: socket, logger: logger)
        let socketConnectionHandler = AutomaticSocketConnectionHandler(socket: socket, subscriptionsTracker: SubscriptionsTracker(logger: logger), logger: logger, socketStatusProvider: socketStatusProvider)
        let dispatcher = Dispatcher(
            socketFactory: webSocketFactory,
            relayUrlFactory: urlFactory,
            networkMonitor: networkMonitor,
            socket: socket,
            logger: logger,
            socketConnectionHandler: socketConnectionHandler,
            socketStatusProvider: socketStatusProvider
        )
        let keychain = KeychainStorageMock()
        let relayClient = RelayClientFactory.create(
            relayHost: InputConfig.relayHost,
            projectId: InputConfig.projectId,
            keyValueStorage: keyValueStorage,
            keychainStorage: keychain,
            socketFactory: DefaultSocketFactory(),
            socketConnectionType: .manual, 
            networkMonitor: networkMonitor,
            logger: logger
        )
        let clientId = try! relayClient.getClientId()
        logger.debug("My client id is: \(clientId)")

        return relayClient
    }

    override func tearDown() {
        relayA = nil
        relayB = nil
        super.tearDown()
    }

    func testSubscribe() {
        relayA = makeRelayClient(prefix: "")

        do {
            try relayA.connect()
        } catch {
            XCTFail("Failed to connect: \(error)")
        }

        let subscribeExpectation = expectation(description: "subscribe call succeeds")
        subscribeExpectation.assertForOverFulfill = true
        relayA.socketConnectionStatusPublisher.sink { [weak self] status in
            guard let self = self else {return}
            if status == .connected {
                Task(priority: .high) {  try await self.relayA.subscribe(topic: "ecb78f2df880c43d3418ddbf871092b847801932e21765b250cc50b9e96a9131") }
                subscribeExpectation.fulfill()
            }
        }.store(in: &publishers)

        wait(for: [subscribeExpectation], timeout: InputConfig.defaultTimeout)
    }

    func testEndToEndPayload() {
        relayA = makeRelayClient(prefix: "⚽️ A ")
        relayB = makeRelayClient(prefix: "🏀 B ")

        do {
            try relayA.connect()
            try relayB.connect()
        } catch {
            XCTFail("Failed to connect: \(error)")
        }
        let randomTopic = String.randomTopic()
        let payloadA = "A"
        let payloadB = "B"
        var subscriptionATopic: String!
        var subscriptionBTopic: String!
        var subscriptionAPayload: String!
        var subscriptionBPayload: String!

        let expectationA = expectation(description: "publish payloads send and receive successfuly")
        let expectationB = expectation(description: "publish payloads send and receive successfuly")

        expectationA.assertForOverFulfill = false
        expectationB.assertForOverFulfill = false

        relayA.messagePublisher.sink { [weak self] topic, payload, _, _ in
            guard let self = self else { return }
            (subscriptionATopic, subscriptionAPayload) = (topic, payload)
            expectationA.fulfill()
        }.store(in: &publishers)

        relayB.messagePublisher.sink { [weak self] topic, payload, _, _ in
            guard let self = self else { return }
            (subscriptionBTopic, subscriptionBPayload) = (topic, payload)
            Task(priority: .high) {
                sleep(1)
                try await self.relayB.publish(topic: randomTopic, payload: payloadB, tag: 0, prompt: false, ttl: 60)
            }
            expectationB.fulfill()
        }.store(in: &publishers)

        relayA.socketConnectionStatusPublisher.sink { [weak self] status in
            guard let self = self else { return }
            guard status == .connected else { return }
            Task(priority: .high) {
                try await self.relayA.subscribe(topic: randomTopic)
                try await self.relayA.publish(topic: randomTopic, payload: payloadA, tag: 0, prompt: false, ttl: 60)
            }
        }.store(in: &publishers)

        relayB.socketConnectionStatusPublisher.sink { [weak self] status in
            guard let self = self else { return }
            guard status == .connected else { return }
            Task(priority: .high) {
                try await self.relayB.subscribe(topic: randomTopic)
            }
        }.store(in: &publishers)

        wait(for: [expectationA, expectationB], timeout: InputConfig.defaultTimeout)

        XCTAssertEqual(subscriptionATopic, randomTopic)
        XCTAssertEqual(subscriptionBTopic, randomTopic)

        XCTAssertEqual(subscriptionBPayload, payloadA)
        XCTAssertEqual(subscriptionAPayload, payloadB)
    }
}

extension String {
    static func randomTopic() -> String {
        "\(UUID().uuidString)\(UUID().uuidString)".replacingOccurrences(of: "-", with: "").lowercased()
    }
}
