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

    func makeRelayClient(prefix: String, projectId: String = InputConfig.projectId) -> RelayClient {
        let keyValueStorage = RuntimeKeyValueStorage()
        let logger = ConsoleLogger(prefix: prefix, loggingLevel: .debug)
        let clientIdStorage = ClientIdStorage(defaults: keyValueStorage, keychain: KeychainStorageMock(), logger: logger)
//        let socketAuthenticator = ClientIdAuthenticator(
//            clientIdStorage: clientIdStorage,
//            logger: ConsoleLoggerMock()
//        )
//        let urlFactory = RelayUrlFactory(
//            relayHost: InputConfig.relayHost,
//            projectId: InputConfig.projectId
//        )
//        let socket = WebSocket(url: urlFactory.create(bundleId: nil))
        let networkMonitor = NetworkMonitor()
//
//        let socketStatusProvider = SocketStatusProvider(socket: socket, logger: logger)
//        let socketConnectionHandler = AutomaticSocketConnectionHandler(socket: socket, subscriptionsTracker: SubscriptionsTracker(logger: logger), logger: logger, socketStatusProvider: socketStatusProvider, clientIdAuthenticator: socketAuthenticator)
        
        let keychain = KeychainStorageMock()
        let relayClient = RelayClientFactory.create(
            relayHost: InputConfig.relayHost,
            projectId: InputConfig.projectId,
            keyValueStorage: keyValueStorage,
            keychainStorage: keychain,
            socketFactory: DefaultSocketFactory(),
            socketConnectionType: .automatic,
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

    // test_bundleId_present - configured in the cloud to include bundleId for whitelisted apps
    func testConnectProjectBundleIdPresent() async {
        let randomTopic = String.randomTopic()
        relayA = makeRelayClient(prefix: "⚽️ X ", projectId: InputConfig.bundleIdPresentProjectId)

        let expectation = expectation(description: "RelayA publishes message successfully")

        Task {
            do {
                try await self.relayA.subscribe(topic: randomTopic)
                expectation.fulfill() // Mark the expectation as fulfilled upon success
            } catch {
                XCTFail("Publish failed with error: \(error)")
            }
        }

        // Wait for the expectation with a timeout
        await fulfillment(of: [expectation], timeout: 20.0) // Set the timeout duration in seconds
    }

    // test_bundleId_not_present - configured in the cloud to not include bundleId for whitelisted apps
    func testConnectProjectBundleIdNotPresent() async {
        let randomTopic = String.randomTopic()
        relayA = makeRelayClient(prefix: "⚽️ X ", projectId: InputConfig.bundleIdNotPresentProjectId)

        let expectation = expectation(description: "RelayA publishes message successfully")

        Task {
            do {
                try await self.relayA.subscribe(topic: randomTopic)
                expectation.fulfill() // Mark the expectation as fulfilled upon success
            } catch {
                XCTFail("Publish failed with error: \(error)")
            }
        }

        // Wait for the expectation with a timeout
        await fulfillment(of: [expectation], timeout: 20.0) // Set the timeout duration in seconds
    }

    func testEndToEndPayload() async throws {
        relayA = makeRelayClient(prefix: "⚽️ A ")
        relayB = makeRelayClient(prefix: "🏀 B ")

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

        relayA.messagePublisher.sink { topic, payload, _, _ in
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

        try await self.relayA.subscribe(topic: randomTopic)
        try await self.relayA.publish(topic: randomTopic, payload: payloadA, tag: 0, prompt: false, ttl: 60)

        try await self.relayB.subscribe(topic: randomTopic)


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
