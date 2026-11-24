import XCTest
import Combine
import JSONRPC
@testable import WalletConnectSign
@testable import WalletConnectUtils
@testable import WalletConnectNetworking
import WalletConnectKMS

final class ProposalExpiryWatcherTests: XCTestCase {

    private static let idleCheckInterval: TimeInterval = 3_600 // timer never fires during the test
    private static let fastCheckInterval: TimeInterval = 0.05
    private static let timeout: TimeInterval = 5
    private static let releasedObservationWindow: TimeInterval = fastCheckInterval * 5 // several periods, so a leaked timer would have fired

    private let referenceDate = Date()
    private var time: TimeProviderMock!
    private var store: CodableStore<RequestSubscriptionPayload<SessionType.ProposeParams>>!
    private var rpcHistory: RPCHistory!
    private var publishers: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        time = TimeProviderMock(currentDate: referenceDate)
        store = CodableStore(defaults: RuntimeKeyValueStorage(), identifier: "proposals")
        rpcHistory = RPCHistoryFactory.createForNetwork(keyValueStorage: RuntimeKeyValueStorage())
    }

    override func tearDown() {
        publishers = []
        rpcHistory = nil
        store = nil
        time = nil
        super.tearDown()
    }

    func testExpiredProposalIsPublishedAndRemoved() throws {
        let sut = makeWatcher()
        var expired: [String] = []
        sut.sessionProposalExpirationPublisher.sink { expired.append($0.id) }.store(in: &publishers)
        let payload = try storeProposal()
        time.currentDate = referenceDate.addingTimeInterval(SessionProposal.proposalTtl + 1)

        sut.checkForProposalsExpiry()
        sut.checkForProposalsExpiry()

        XCTAssertEqual(expired, [payload.request.proposer.publicKey])
        XCTAssertTrue(store.getAll().isEmpty)
        XCTAssertNil(rpcHistory.get(recordId: payload.id))
    }

    func testProposalBeforeExpiryIsKept() throws {
        let sut = makeWatcher()
        var expired: [String] = []
        sut.sessionProposalExpirationPublisher.sink { expired.append($0.id) }.store(in: &publishers)
        let payload = try storeProposal()

        sut.checkForProposalsExpiry()

        XCTAssertEqual(expired, [])
        XCTAssertEqual(store.getAll().count, 1)
        XCTAssertNotNil(rpcHistory.get(recordId: payload.id))
    }

    func testWatcherCreatedOffMainThreadChecksOnMainThread() async throws {
        let sut = await Task.detached { [store, rpcHistory, time] in
            ProposalExpiryWatcher(proposalPayloadsStore: store!, rpcHistory: rpcHistory!, timeProvider: time!, checkInterval: Self.fastCheckInterval)
        }.value
        let published = expectation(description: "expiration published")
        var expiredId: String?
        sut.sessionProposalExpirationPublisher
            .sink { proposal in
                XCTAssertTrue(Thread.isMainThread)
                expiredId = proposal.id
                published.fulfill()
            }
            .store(in: &publishers)

        let payload = try storeProposal()
        time.currentDate = referenceDate.addingTimeInterval(SessionProposal.proposalTtl + 1)

        await fulfillment(of: [published], timeout: Self.timeout)
        XCTAssertEqual(expiredId, payload.request.proposer.publicKey)
    }

    func testReleasedWatcherStopsChecking() throws {
        weak var weakWatcher: ProposalExpiryWatcher?
        autoreleasepool {
            let watcher = makeWatcher(checkInterval: Self.fastCheckInterval)
            weakWatcher = watcher
        }
        XCTAssertNil(weakWatcher)

        let payload = try storeProposal()
        time.currentDate = referenceDate.addingTimeInterval(SessionProposal.proposalTtl + 1)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: Self.releasedObservationWindow))

        XCTAssertNotNil(try store.get(key: payload.request.proposer.publicKey))
        XCTAssertNotNil(rpcHistory.get(recordId: payload.id))
    }

    // MARK: - Helpers

    private func makeWatcher(checkInterval: TimeInterval = idleCheckInterval) -> ProposalExpiryWatcher {
        ProposalExpiryWatcher(
            proposalPayloadsStore: store,
            rpcHistory: rpcHistory,
            timeProvider: time,
            checkInterval: checkInterval
        )
    }

    @discardableResult
    private func storeProposal() throws -> RequestSubscriptionPayload<SessionType.ProposeParams> {
        let proposal = SessionProposal.stub(proposerPubKey: AgreementPrivateKey().publicKey.hexRepresentation)
        let request = RPCRequest(method: "wc_sessionPropose", params: proposal)
        try rpcHistory.set(request, forTopic: "pairing", emmitedBy: .remote, transportType: .relay)
        let payload = RequestSubscriptionPayload(
            id: request.id!,
            topic: "pairing",
            request: proposal,
            decryptedPayload: Data(),
            publishedAt: referenceDate,
            derivedTopic: nil,
            encryptedMessage: "",
            attestation: nil
        )
        store.set(payload, forKey: proposal.proposer.publicKey)
        return payload
    }
}

private final class TimeProviderMock: TimeProvider {
    private let lock = NSLock()
    private var date: Date

    init(currentDate: Date) {
        self.date = currentDate
    }

    var currentDate: Date {
        get {
            lock.lock(); defer { lock.unlock() }
            return date
        }
        set {
            lock.lock(); defer { lock.unlock() }
            date = newValue
        }
    }
}
