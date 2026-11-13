
import Foundation
import Combine

class RequestsExpiryWatcher {

    static let defaultCheckInterval: TimeInterval = 3

    private let requestExpirationPublisherSubject: PassthroughSubject<RPCID, Never> = .init()
    private let rpcHistory: RPCHistory
    private let historyService: HistoryService
    private let timeProvider: TimeProvider
    private let deliveryQueue: DispatchQueue
    private let checkTimer: DispatchSourceTimer

    var requestExpirationPublisher: AnyPublisher<RPCID, Never> {
        return requestExpirationPublisherSubject.eraseToAnyPublisher()
    }

    internal init(
        proposalPayloadsStore: CodableStore<RequestSubscriptionPayload<SessionType.ProposeParams>>,
        rpcHistory: RPCHistory,
        historyService: HistoryService,
        timeProvider: TimeProvider = DefaultTimeProvider(),
        checkInterval: TimeInterval = RequestsExpiryWatcher.defaultCheckInterval,
        checkQueue: DispatchQueue = DispatchQueue(label: "com.walletconnect.sdk.requests_expiry_watcher", qos: .utility),
        deliveryQueue: DispatchQueue = .main
    ) {
        precondition(checkInterval > 0)
        self.rpcHistory = rpcHistory
        self.historyService = historyService
        self.timeProvider = timeProvider
        self.deliveryQueue = deliveryQueue
        self.checkTimer = DispatchSource.makeTimerSource(queue: checkQueue)
        checkTimer.schedule(deadline: .now() + checkInterval, repeating: checkInterval)
        checkTimer.setEventHandler { [weak self] in
            self?.checkForRequestExpiry()
        }
        checkTimer.resume()
    }

    deinit {
        checkTimer.cancel()
    }

    func checkForRequestExpiry() {
        let now = timeProvider.currentDate
        let expiredIds = historyService.getPendingExpirableRequestsWithId()
            .filter { request, _ in request.isExpired(currentDate: now) }
            .map { _, recordId in recordId }
        guard !expiredIds.isEmpty else { return }

        // Responses handled on the delivery queue (e.g. Link Mode on main) cannot interleave with this.
        deliveryQueue.async { [weak self] in
            guard let self = self else { return }
            for recordId in expiredIds where self.rpcHistory.get(recordId: recordId) != nil {
                self.requestExpirationPublisherSubject.send(recordId)
                self.rpcHistory.delete(id: recordId)
            }
        }
    }

}
