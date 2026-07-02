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

    private let fetchResponsePublisherSubject = PassthroughSubject<(RPCID?, FetchMessagesResult), Never>()
    private var fetchResponsePublisher: AnyPublisher<(RPCID?, FetchMessagesResult), Never> {
        fetchResponsePublisherSubject.eraseToAnyPublisher()
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
    
    public func proposeSession(pairingTopic: String, sessionProposal: String, correlationId: RPCID?) async throws {
        let request = ProposeSession(params: .init(pairingTopic: pairingTopic, sessionProposal: sessionProposal, correlationId: correlationId)).asRPCRequest()
        let message = try request.asJSONEncodedString()
        try await dispatcher.protectedSend(message, connectUnconditionally: true)
        topicsTracker.addTopics([pairingTopic])
        subscriptionsTracker.setSubscription(for: pairingTopic, id: UUID().uuidString)
    }
    
    public func approveSession(pairingTopic: String, sessionTopic: String, sessionProposalResponse: String, sessionSettlementRequest: String, correlationId: RPCID?, approvedChains: [String], approvedMethods: [String], approvedEvents: [String]) async throws {
        let params = ApproveSession.Params(
            pairingTopic: pairingTopic,
            sessionTopic: sessionTopic,
            sessionProposalResponse: sessionProposalResponse,
            sessionSettlementRequest: sessionSettlementRequest,
            correlationId: correlationId,
            approvedChains: approvedChains,
            approvedMethods: approvedMethods,
            approvedEvents: approvedEvents
        )
        let request = ApproveSession(params: params).asRPCRequest()
        let message = try request.asJSONEncodedString()
        try await dispatcher.protectedSend(message, connectUnconditionally: true)
        topicsTracker.addTopics([sessionTopic])
        subscriptionsTracker.setSubscription(for: sessionTopic, id: UUID().uuidString)
    }

    public func subscribe(topic: String, connectUnconditionally: Bool = false, fetchMailbox: Bool = false) async throws {
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

        // The relay does not always push messages that were mailboxed while we had no active
        // subscription (e.g. a wc_sessionAuthenticate request published on the pairing topic
        // before the wallet paired). Only the caller knows whether a topic can have such
        // pre-subscription messages, so mailbox fetching is opt-in to avoid extra relay
        // requests on topics that only ever receive live messages (session topics, etc.).
        if fetchMailbox {
            await fetchMessages(topic: topic)
        }
    }

    /// Maximum number of `hasMore` follow-up fetches, to bound pagination against a
    /// misbehaving relay that never stops returning `hasMore == true`.
    private static let maxFetchPages = 50

    /// Fetches and dispatches any messages held in the relay mailbox for `topic`.
    /// Best-effort: failures are logged and swallowed so subscription still succeeds.
    func fetchMessages(topic: String, page: Int = 0) async {
        do {
            let rpc = FetchMessage(params: .init(topic: topic))
            let hasMore = try await performFetch(rpc.asRPCRequest(), label: "topic: \(topic)")
            if hasMore, page + 1 < Self.maxFetchPages {
                await fetchMessages(topic: topic, page: page + 1)
            }
        } catch {
            logger.warn("[FetchMessages] Failed to fetch mailbox messages for topic: \(topic), error: \(error)")
        }
    }

    /// Sends a fetch/batch-fetch request, dispatches the returned messages into the normal
    /// inbound pipeline, and reports whether the relay signalled more messages are pending.
    private func performFetch(_ request: RPCRequest, label: String) async throws -> Bool {
        guard let requestId = request.id else { return false }
        let message = try request.asJSONEncodedString()

        logger.debug("[FetchMessages] Fetching mailbox messages for \(label)")

        let result: FetchMessagesResult = try await withUnsafeThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = fetchResponsePublisher
                .filter { $0.0 == requestId }
                .map { $0.1 }
                .setFailureType(to: RelayError.self)
                .timeout(.seconds(30), scheduler: concurrentQueue, customError: { .requestTimeout })
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        cancellable?.cancel()
                        self?.logger.debug("[FetchMessages] Timeout for \(label)")
                        continuation.resume(throwing: error)
                    }
                }, receiveValue: { value in
                    cancellable?.cancel()
                    continuation.resume(returning: value)
                })

            Task {
                do {
                    try await dispatcher.protectedSend(message, connectUnconditionally: true)
                } catch {
                    cancellable?.cancel()
                    continuation.resume(throwing: error)
                }
            }
        }

        logger.debug("[FetchMessages] Received \(result.messages.count) mailbox message(s) for \(label)")
        for received in result.messages {
            messagePublisherSubject.send((received.topic, received.message, received.publishedAt, received.attestation))
        }
        return result.hasMore == true
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
        logger.debug("Unsubscribing from topic: \(topic)")
        let rpc = Unsubscribe(params: .init(topic: topic))
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

    public func getSubscribedTopics() -> [String] {
        return subscriptionsTracker.getTopics()
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
                if let fetchResult = try? anyCodable.get(FetchMessagesResult.self) {
                    fetchResponsePublisherSubject.send((response.id, fetchResult))
                } else if let _ = try? anyCodable.get(Bool.self) {
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
