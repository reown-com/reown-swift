import Foundation
import Combine

public enum SocketConnectionStatus {
    case connected
    case disconnected
}

/// WalletConnect Relay Client
///
/// Should not be instantiated outside of the SDK
///
/// Access via `Relay.instance`
public final class RelayClient {

    #if DEBUG
    var blockPublishing: Bool = false
    #endif
    enum Errors: Error {
        case subscriptionIdNotFound
    }

    public var isSocketConnected: Bool {
        return dispatcher.isSocketConnected
    }

    public var messagePublisher: AnyPublisher<(topic: String, message: String, publishedAt: Date, attestation: String?), Never> {
        messagePublisherSubject.eraseToAnyPublisher()
    }

    public var socketConnectionStatusPublisher: AnyPublisher<SocketConnectionStatus, Never> {
        dispatcher.socketConnectionStatusPublisher
    }

    public var networkConnectionStatusPublisher: AnyPublisher<NetworkConnectionStatus, Never> {
        dispatcher.networkConnectionStatusPublisher
    }

    private let messagePublisherSubject = PassthroughSubject<(topic: String, message: String, publishedAt: Date, attestation: String?), Never>()

    private let subscriptionResponsePublisherSubject = PassthroughSubject<(RPCID?, [String]), Never>()
    private var subscriptionResponsePublisher: AnyPublisher<(RPCID?, [String]), Never> {
        subscriptionResponsePublisherSubject.eraseToAnyPublisher()
    }

    private let requestAcknowledgePublisherSubject = PassthroughSubject<RPCID?, Never>()
    private var requestAcknowledgePublisher: AnyPublisher<RPCID?, Never> {
        requestAcknowledgePublisherSubject.eraseToAnyPublisher()
    }
    private var publishers = [AnyCancellable]()

    private let clientIdStorage: ClientIdStoring

    private var dispatcher: Dispatching
    private let rpcHistory: RPCHistory
    private let logger: ConsoleLogging
    private let subscriptionsTracker: SubscriptionsTracking
    private let topicsTracker: TopicsTracking


    private let concurrentQueue = DispatchQueue(label: "com.walletconnect.sdk.relay_client", qos: .utility, attributes: .concurrent)

    public var logsPublisher: AnyPublisher<Log, Never> {
        logger.logsPublisher
            .eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(
        dispatcher: Dispatching,
        logger: ConsoleLogging,
        rpcHistory: RPCHistory,
        clientIdStorage: ClientIdStoring,
        subscriptionsTracker: SubscriptionsTracking,
        topicsTracker: TopicsTracking
    ) {
        self.logger = logger
        self.dispatcher = dispatcher
        self.rpcHistory = rpcHistory
        self.clientIdStorage = clientIdStorage
        self.subscriptionsTracker = subscriptionsTracker
        self.topicsTracker = topicsTracker
        setUpBindings()
        setupConnectionSubscriptions()
    }

    private func setUpBindings() {
        dispatcher.onMessage = { [weak self] payload in
            self?.handlePayloadMessage(payload)
        }
    }

    private func setupConnectionSubscriptions() {
        socketConnectionStatusPublisher
            .sink { [weak self] status in
                guard let self = self else { return }
                guard status == .connected else { return }
                let topics = self.topicsTracker.getAllTopics()
                Task(priority: .high) {
                    try await self.batchSubscribe(topics: topics)
                }
            }
            .store(in: &publishers)
    }

    public func setLogging(level: LoggingLevel) {
        logger.setLogging(level: level)
    }

    /// Connects web socket
    ///
    /// Use this method for manual socket connection only
    public func connect() throws {
        try dispatcher.connect()
    }

    /// Disconnects web socket
    ///
    /// Use this method for manual socket connection only
    public func disconnect(closeCode: URLSessionWebSocketTask.CloseCode) throws {
        try dispatcher.disconnect(closeCode: closeCode)
    }

    /// Completes with an acknowledgement from the relay network
    public func publish(topic: String, payload: String, tag: Int, prompt: Bool, ttl: Int, tvfData: TVFData?, coorelationId: RPCID?) async throws {
        #if DEBUG
        if blockPublishing {
            logger.debug("[Publish] Publishing is blocked")
            return
        }
        #endif
        let request = Publish(params: .init(topic: topic, message: payload, ttl: ttl, prompt: prompt, tag: tag, correlationId: coorelationId, tvfData: tvfData)).asRPCRequest()
        let message = try request.asJSONEncodedString()
        
        logger.debug("[Publish] Sending payload on topic: \(topic)")

        try await dispatcher.protectedSend(message, connectUnconditionally: true)

        return try await withUnsafeThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = requestAcknowledgePublisher
                .filter { $0 == request.id }
                .setFailureType(to: RelayError.self)
                .timeout(.seconds(60), scheduler: concurrentQueue, customError: { .requestTimeout })
                .sink(receiveCompletion: { [unowned self] result in
                    switch result {
                    case .failure(let error):
                        cancellable?.cancel()
                        logger.debug("[Publish] Relay request timeout for topic: \(topic)")
                        continuation.resume(throwing: error)
                    case .finished: break
                    }
                }, receiveValue: { [unowned self] _ in
                    cancellable?.cancel()
                    logger.debug("[Publish] Published payload on topic: \(topic)")
                    continuation.resume(returning: ())
                })
        }
    }
    
    public func proposeSession(pairingTopic: String, sessionProposal: String) async throws {
        let request = ProposeSession(params: .init(pairingTopic: pairingTopic, sessionProposal: sessionProposal)).asRPCRequest()
        let message = try request.asJSONEncodedString()
        try await dispatcher.protectedSend(message, connectUnconditionally: true)
    }

    public func subscribe(topic: String, connectUnconditionally: Bool = false) async throws {
        topicsTracker.addTopics([topic])
        logger.debug("[Subscribe] Subscribing to topic: \(topic)")

        let rpc = Subscribe(params: .init(topic: topic))
        let request = rpc.asRPCRequest()
        let message = try request.asJSONEncodedString()

        try await dispatcher.protectedSend(message, connectUnconditionally: connectUnconditionally)

        // Wait for relay's subscription response
        try await waitForSubscriptionResponse(
            requestId: request.id!,
            topics: [topic],
            logPrefix: "[Subscribe]"
        )
    }

    public func batchSubscribe(topics: [String]) async throws {
        topicsTracker.addTopics(topics)

        guard !topics.isEmpty else { return }
        logger.debug("[BatchSubscribe] Subscribing to topics: \(topics)")

        let rpc = BatchSubscribe(params: .init(topics: topics))
        let request = rpc.asRPCRequest()
        let message = try request.asJSONEncodedString()

        try await dispatcher.protectedSend(message)

        // Same wait, but for multiple topics
        try await waitForSubscriptionResponse(
            requestId: request.id!,
            topics: topics,
            logPrefix: "[BatchSubscribe]"
        )
    }

    private func waitForSubscriptionResponse(
        requestId: RPCID,
        topics: [String],
        logPrefix: String
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var cancellable: AnyCancellable?

            cancellable = subscriptionResponsePublisher
                // Only handle responses matching this request ID
                .filter { $0.0 == requestId }
                // Convert Never to RelayError so we can throw on timeout
                .setFailureType(to: RelayError.self)
                // Enforce a 30-second timeout
                .timeout(.seconds(30), scheduler: concurrentQueue, customError: { .requestTimeout })
                .sink(
                    receiveCompletion: { [unowned self] completion in
                        switch completion {
                        case .failure(let error):
                            cancellable?.cancel()
                            logger.debug("\(logPrefix) Relay request timeout for topics: \(topics)")
                            continuation.resume(throwing: error)
                        case .finished:
                            // Not typically called in this pattern, but required by Combine
                            break
                        }
                    },
                    receiveValue: { [unowned self] (_, subscriptionIds) in
                        cancellable?.cancel()
                        logger.debug("\(logPrefix) Subscribed to topics: \(topics)")

                        // Check ID counts, warn if mismatch
                        guard topics.count == subscriptionIds.count else {
                            logger.warn("\(logPrefix) Number of returned subscription IDs != number of topics")
                            continuation.resume(returning: ())
                            return
                        }

                        // Track each subscription
                        for (i, topic) in topics.enumerated() {
                            subscriptionsTracker.setSubscription(for: topic, id: subscriptionIds[i])
                        }

                        continuation.resume(returning: ())
                    }
                )
        }
    }

    public func unsubscribe(topic: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            unsubscribe(topic: topic) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public func batchUnsubscribe(topics: [String]) async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            for topic in topics {
                group.addTask {
                    try await self.unsubscribe(topic: topic)
                }
            }
        }
    }

    public func unsubscribe(topic: String, completion: ((Error?) -> Void)?) {
        guard let subscriptionId = subscriptionsTracker.getSubscription(for: topic) else {
            completion?(Errors.subscriptionIdNotFound)
            return
        }
        logger.debug("Unsubscribing from topic: \(topic)")
        let rpc = Unsubscribe(params: .init(id: subscriptionId, topic: topic))
        let request = rpc.asRPCRequest()
        let message = try! request.asJSONEncodedString()
        rpcHistory.deleteAll(forTopic: topic)
        dispatcher.protectedSend(message) { [weak self] error in
            if let error = error {
                self?.logger.debug("Failed to unsubscribe from topic")
                completion?(error)
            } else {
                self?.subscriptionsTracker.removeSubscription(for: topic)
                self?.topicsTracker.removeTopics([topic])
                completion?(nil)
            }
        }
    }

    public func getClientId() throws -> String {
        try clientIdStorage.getClientId()
    }
    
    public func trackTopics(_ topics: [String]) {
        topicsTracker.addTopics(topics)
    }

    // FIXME: Parse data to string once before trying to decode -> respond error on fail
    private func handlePayloadMessage(_ payload: String) {
        if let request = tryDecode(RPCRequest.self, from: payload) {
            if let params = try? request.params?.get(Subscription.Params.self) {
                do {
                    try acknowledgeRequest(request)
                    try rpcHistory.set(request, forTopic: params.data.topic, emmitedBy: .remote, transportType: .relay)
                    logger.debug("received message: \(params.data.message) on topic: \(params.data.topic)")
                    messagePublisherSubject.send((params.data.topic, params.data.message, params.data.publishedAt, params.data.attestation))
                } catch {
                    logger.error("RPC History 'set()' error: \(error)")
                }
            } else {
                logger.error("Unexpected request from network")
            }
        } else if let response = tryDecode(RPCResponse.self, from: payload) {
            switch response.outcome {
            case .response(let anyCodable):
                if let _ = try? anyCodable.get(Bool.self) {
                    requestAcknowledgePublisherSubject.send(response.id)
                } else if let subscriptionId = try? anyCodable.get(String.self) {
                    subscriptionResponsePublisherSubject.send((response.id, [subscriptionId]))
                } else if let subscriptionIds = try? anyCodable.get([String].self) {
                    subscriptionResponsePublisherSubject.send((response.id, subscriptionIds))
                }
            case .error(let rpcError):
                logger.error("Received RPC error from relay network: \(rpcError)")
            }
        } else {
            logger.error("Unexpected request/response from network")
        }
    }

    private func tryDecode<T: Decodable>(_ type: T.Type, from payload: String) -> T? {
        if let data = payload.data(using: .utf8),
           let response = try? JSONDecoder().decode(T.self, from: data) {
            return response
        } else {
            return nil
        }
    }

    private func acknowledgeRequest(_ request: RPCRequest) throws {
        let response = RPCResponse(matchingRequest: request, result: true)
        let message = try response.asJSONEncodedString()
        dispatcher.protectedSend(message) { [unowned self] in
            if let error = $0 {
                logger.debug("Failed to dispatch response: \(response), error: \(error)")
            } else {
                do {
                    try rpcHistory.resolve(response)
                } catch {
                    logger.debug("\(error)")
                }
            }
        }
    }
}
