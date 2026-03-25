import Foundation

final class TopicReconciliationService {

    private let networkingInteractor: NetworkInteracting
    private let sessionStore: WCSessionStorage
    private let pairingStore: WCPairingStorage
    private let authResponseTopicRecordsStore: CodableStore<AuthResponseTopicRecord>
    private let logger: ConsoleLogging
    private var reconciliationTimer: Timer?

    deinit {
        reconciliationTimer?.invalidate()
    }

    init(
        networkingInteractor: NetworkInteracting,
        sessionStore: WCSessionStorage,
        pairingStore: WCPairingStorage,
        authResponseTopicRecordsStore: CodableStore<AuthResponseTopicRecord>,
        logger: ConsoleLogging
    ) {
        self.networkingInteractor = networkingInteractor
        self.sessionStore = sessionStore
        self.pairingStore = pairingStore
        self.authResponseTopicRecordsStore = authResponseTopicRecordsStore
        self.logger = logger
        startReconciliation()
    }

    private func startReconciliation() {
        reconciliationTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.reconcile()
        }
    }

    func reconcile() {
        let subscribedTopics = Set(networkingInteractor.getSubscribedTopics())
        guard !subscribedTopics.isEmpty else { return }

        let sessionTopics = Set(sessionStore.getAll().map { $0.topic })
        let pairingTopics = Set(pairingStore.getAll().map { $0.topic })
        let authTopics = Set(authResponseTopicRecordsStore.getAll().map { $0.topic })

        let knownTopics = sessionTopics.union(pairingTopics).union(authTopics)
        let orphanedTopics = subscribedTopics.subtracting(knownTopics)

        for topic in orphanedTopics {
            logger.debug("Reconciliation: unsubscribing orphaned topic \(topic)")
            networkingInteractor.unsubscribe(topic: topic)
        }
    }
}
