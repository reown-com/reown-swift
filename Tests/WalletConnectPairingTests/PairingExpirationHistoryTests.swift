import XCTest
import Combine
import JSONRPC
@testable import WalletConnectPairing
@testable import WalletConnectRelay
@testable import TestingUtils
@testable import WalletConnectKMS
import WalletConnectUtils
import WalletConnectNetworking

final class PairingExpirationHistoryTests: XCTestCase {

    private var dispatcher: DispatcherStub!
    private var rpcHistory: RPCHistory!
    private var pairingStorage: WCPairingStorageMock!
    private var service: ExpirationService!

    override func setUp() {
        dispatcher = DispatcherStub()
        rpcHistory = RPCHistoryFactory.createForNetwork(keyValueStorage: RuntimeKeyValueStorage())
        let logger = ConsoleLoggerMock()
        let relayClient = RelayClient(
            dispatcher: dispatcher,
            logger: logger,
            rpcHistory: RPCHistoryFactory.createForRelay(keyValueStorage: RuntimeKeyValueStorage()),
            clientIdStorage: ClientIdStorageStub(),
            subscriptionsTracker: SubscriptionsTrackerMock(),
            topicsTracker: TopicsTrackerMock()
        )
        let kms = KeyManagementServiceMock()
        let networkingInteractor = NetworkingInteractor(
            relayClient: relayClient,
            serializer: Serializer(kms: kms, logger: logger),
            logger: logger,
            rpcHistory: rpcHistory
        )
        pairingStorage = WCPairingStorageMock()
        service = ExpirationService(pairingStorage: pairingStorage, networkInteractor: networkingInteractor, kms: kms)
        service.setupExpirationHandling()
    }

    func testExpiredPairingRemovesHistoryWhenUnsubscribeFails() throws {
        dispatcher.sendError = URLError(.notConnectedToInternet)
        let pairing = WCPairing.stub()
        let expiredRequest = try storeProposal(onTopic: pairing.topic)
        let otherRequest = try storeProposal(onTopic: WCPairing.stub().topic)

        pairingStorage.onPairingExpiration?(pairing)

        XCTAssertNil(rpcHistory.get(recordId: expiredRequest.id!))
        XCTAssertNotNil(rpcHistory.get(recordId: otherRequest.id!))
    }

    func testExpiredPairingRemovesHistoryAndSendsUnsubscribe() throws {
        let pairing = WCPairing.stub()
        let request = try storeProposal(onTopic: pairing.topic)

        pairingStorage.onPairingExpiration?(pairing)

        XCTAssertNil(rpcHistory.get(recordId: request.id!))
        let sent = try dispatcher.sentMessages.map { try JSONDecoder().decode(RPCRequest.self, from: Data($0.utf8)) }
        XCTAssertEqual(sent.map(\.method), [Unsubscribe(params: .init(topic: pairing.topic)).method])
        XCTAssertEqual(try sent.first?.params?.get(Unsubscribe.Params.self).topic, pairing.topic)
    }

    private func storeProposal(onTopic topic: String) throws -> RPCRequest {
        let request = RPCRequest(method: "wc_sessionPropose", params: ["a": "b"])
        try rpcHistory.set(request, forTopic: topic, emmitedBy: .local, transportType: .relay)
        return request
    }
}

private final class DispatcherStub: Dispatching {
    var sendError: Error?
    private(set) var sentMessages: [String] = []
    var onMessage: ((String) -> Void)?
    var isSocketConnected = false
    var networkConnectionStatusPublisher: AnyPublisher<NetworkConnectionStatus, Never> { Just(.connected).eraseToAnyPublisher() }
    var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> { Just(.disconnected).eraseToAnyPublisher() }

    func protectedSend(_ string: String, connectUnconditionally: Bool, completion: @escaping (Error?) -> Void) {
        if sendError == nil { sentMessages.append(string) }
        completion(sendError)
    }

    func protectedSend(_ string: String, connectUnconditionally: Bool) async throws {
        if let sendError { throw sendError }
    }

    func connect() throws {}
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {}
}

private struct ClientIdStorageStub: ClientIdStoring {
    private let key = SigningPrivateKey()
    func getOrCreateKeyPair() throws -> SigningPrivateKey { key }
    func getClientId() throws -> String { "client" }
}
