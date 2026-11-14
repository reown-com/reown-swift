import Foundation
import Combine

class ProposalExpiryWatcher {

    static let defaultCheckInterval: TimeInterval = 3

    private let sessionProposalExpirationPublisherSubject: PassthroughSubject<Session.Proposal, Never> = .init()
    private let rpcHistory: RPCHistory
    private let timeProvider: TimeProvider
    private let checkTimer: DispatchSourceTimer

    var sessionProposalExpirationPublisher: AnyPublisher<Session.Proposal, Never> {
        return sessionProposalExpirationPublisherSubject.eraseToAnyPublisher()
    }

    private let proposalPayloadsStore: CodableStore<RequestSubscriptionPayload<SessionType.ProposeParams>>

    internal init(
        proposalPayloadsStore: CodableStore<RequestSubscriptionPayload<SessionType.ProposeParams>>,
        rpcHistory: RPCHistory,
        timeProvider: TimeProvider = DefaultTimeProvider(),
        checkInterval: TimeInterval = ProposalExpiryWatcher.defaultCheckInterval,
        checkQueue: DispatchQueue = .main
    ) {
        precondition(checkInterval > 0)
        self.proposalPayloadsStore = proposalPayloadsStore
        self.rpcHistory = rpcHistory
        self.timeProvider = timeProvider
        self.checkTimer = DispatchSource.makeTimerSource(queue: checkQueue)
        checkTimer.schedule(deadline: .now() + checkInterval, repeating: checkInterval)
        checkTimer.setEventHandler { [weak self] in
            self?.checkForProposalsExpiry()
        }
        checkTimer.resume()
    }

    deinit {
        checkTimer.cancel()
    }

    func checkForProposalsExpiry() {
        let now = timeProvider.currentDate
        let proposals = proposalPayloadsStore.getAll()
        proposals.forEach { proposalPayload in
            let pairingTopic = proposalPayload.topic
            guard proposalPayload.request.isExpired(currentDate: now) else { return }
            sessionProposalExpirationPublisherSubject.send(proposalPayload.request.publicRepresentation(pairingTopic: pairingTopic))
            proposalPayloadsStore.delete(forKey: proposalPayload.request.proposer.publicKey)
            rpcHistory.delete(id: proposalPayload.id)
        }
    }
}
