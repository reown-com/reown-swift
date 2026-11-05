import XCTest
import Combine
import JSONRPC
@testable import WalletConnectSign
@testable import WalletConnectUtils

final class RequestsExpiryWatcherTests: XCTestCase {

    private static let idleCheckInterval: TimeInterval = 3_600 // timer never fires during the test
    private static let fastCheckInterval: TimeInterval = 0.05
    private static let timeout: TimeInterval = 5
    private static let requestLifetime: TimeInterval = 300

    private let referenceDate = Date()
    private var time: TimeProviderMock!
    private var storage: RuntimeKeyValueStorage!
    private var rpcHistory: RPCHistory!
    private var historyService: HistoryService!
    private var publishers: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        time = TimeProviderMock(currentDate: referenceDate)
        storage = RuntimeKeyValueStorage()
        rpcHistory = RPCHistoryFactory.createForNetwork(keyValueStorage: storage)
        historyService = HistoryService(
            history: rpcHistory,
            verifyContextStore: CodableStore(defaults: storage, identifier: "verifyContext")
        )
    }

    override func tearDown() {
        publishers = []
        historyService = nil
        rpcHistory = nil
        storage = nil
        time = nil
        super.tearDown()
    }

    func testExpiredRequestIsPublishedOnceAndRemoved() throws {
        let sut = makeWatcher()
        let expired = collectExpirations(from: sut)
        let id = try storeSessionRequest(expiringAt: referenceDate)
        time.currentDate = referenceDate.addingTimeInterval(1)

        sut.checkForRequestExpiry()
        sut.checkForRequestExpiry()
        drainMainQueue()

        XCTAssertEqual(expired.ids, [id])
        XCTAssertNil(rpcHistory.get(recordId: id))
    }

    func testRequestBeforeExpiryIsKept() throws {
        let sut = makeWatcher()
        let expired = collectExpirations(from: sut)
        let id = try storeSessionRequest(expiringAt: referenceDate.addingTimeInterval(Self.requestLifetime))

        sut.checkForRequestExpiry()
        drainMainQueue()

        XCTAssertEqual(expired.ids, [])
        XCTAssertNotNil(rpcHistory.get(recordId: id))
    }

    func testOnlyExpiredRequestsArePublished() throws {
        let sut = makeWatcher()
        let expired = collectExpirations(from: sut)
        let expiredId = try storeSessionRequest(expiringAt: referenceDate)
        let liveId = try storeSessionRequest(expiringAt: referenceDate.addingTimeInterval(Self.requestLifetime))
        time.currentDate = referenceDate.addingTimeInterval(1)

        sut.checkForRequestExpiry()
        drainMainQueue()

        XCTAssertEqual(expired.ids, [expiredId])
        XCTAssertNotNil(rpcHistory.get(recordId: liveId))
    }

    func testAnsweredRequestIsNotExpired() throws {
        let sut = makeWatcher()
        let expired = collectExpirations(from: sut)
        let request = makeSessionRequest(expiringAt: referenceDate)
        try rpcHistory.set(request, forTopic: "topic", emmitedBy: .remote, transportType: .relay)
        try rpcHistory.resolve(RPCResponse(matchingRequest: request, result: true))
        time.currentDate = referenceDate.addingTimeInterval(1)

        sut.checkForRequestExpiry()
        drainMainQueue()

        XCTAssertEqual(expired.ids, [])
    }

    func testRequestAnsweredOnMainAfterCheckIsNotExpired() throws {
        let sut = makeWatcher()
        let expired = collectExpirations(from: sut)
        let request = makeSessionRequest(expiringAt: referenceDate)
        try rpcHistory.set(request, forTopic: "topic", emmitedBy: .local, transportType: .linkMode)
        time.currentDate = referenceDate.addingTimeInterval(1)

        sut.checkForRequestExpiry()
        try rpcHistory.resolve(RPCResponse(matchingRequest: request, result: true))
        drainMainQueue()

        XCTAssertEqual(expired.ids, [])
    }

    func testTimerChecksOffMainThreadAndPublishesOnMainThread() throws {
        let sut = makeWatcher(checkInterval: Self.fastCheckInterval)
        let id = try storeSessionRequest(expiringAt: referenceDate)
        time.currentDate = referenceDate.addingTimeInterval(1)

        let published = expectation(description: "expiration published")
        sut.requestExpirationPublisher
            .sink { recordId in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(recordId, id)
                published.fulfill()
            }
            .store(in: &publishers)

        wait(for: [published], timeout: Self.timeout)
        XCTAssertGreaterThan(time.readCount, 0)
        XCTAssertEqual(time.mainThreadReadCount, 0)
    }

    func testReleasedWatcherStopsChecking() throws {
        let checkQueue = DispatchQueue(label: "RequestsExpiryWatcherTests.check")
        checkQueue.suspend()
        weak var weakWatcher: RequestsExpiryWatcher?
        autoreleasepool {
            let watcher = makeWatcher(checkInterval: Self.fastCheckInterval, checkQueue: checkQueue)
            weakWatcher = watcher
        }
        XCTAssertNil(weakWatcher)

        let id = try storeSessionRequest(expiringAt: referenceDate)
        time.currentDate = referenceDate.addingTimeInterval(1)
        checkQueue.resume()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: Self.fastCheckInterval * 5))

        XCTAssertNotNil(rpcHistory.get(recordId: id))
        XCTAssertEqual(time.readCount, 0)
    }

    // MARK: - Helpers

    private func makeWatcher(
        checkInterval: TimeInterval = idleCheckInterval,
        checkQueue: DispatchQueue = DispatchQueue(label: "RequestsExpiryWatcherTests.check")
    ) -> RequestsExpiryWatcher {
        RequestsExpiryWatcher(
            proposalPayloadsStore: CodableStore(defaults: storage, identifier: "proposals"),
            rpcHistory: rpcHistory,
            historyService: historyService,
            timeProvider: time,
            checkInterval: checkInterval,
            checkQueue: checkQueue
        )
    }

    private func makeSessionRequest(expiringAt expiry: Date) -> RPCRequest {
        RPCRequest.stubRequest(
            method: "personal_sign",
            chainId: Blockchain("eip155:1")!,
            expiry: UInt64(expiry.timeIntervalSince1970)
        )
    }

    @discardableResult
    private func storeSessionRequest(expiringAt expiry: Date) throws -> RPCID {
        let request = makeSessionRequest(expiringAt: expiry)
        try rpcHistory.set(request, forTopic: "topic", emmitedBy: .remote, transportType: .relay)
        return try XCTUnwrap(request.id)
    }

    private func collectExpirations(from watcher: RequestsExpiryWatcher) -> ExpirationRecorder {
        let recorder = ExpirationRecorder()
        watcher.requestExpirationPublisher
            .sink { recorder.ids.append($0) }
            .store(in: &publishers)
        return recorder
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: Self.timeout)
    }
}

private final class ExpirationRecorder {
    var ids: [RPCID] = []
}

private final class TimeProviderMock: TimeProvider {
    private let lock = NSLock()
    private var date: Date
    private var reads = 0
    private var mainThreadReads = 0

    init(currentDate: Date) {
        self.date = currentDate
    }

    var currentDate: Date {
        get {
            lock.lock(); defer { lock.unlock() }
            reads += 1
            if Thread.isMainThread { mainThreadReads += 1 }
            return date
        }
        set {
            lock.lock(); defer { lock.unlock() }
            date = newValue
        }
    }

    var readCount: Int {
        lock.lock(); defer { lock.unlock() }
        return reads
    }

    var mainThreadReadCount: Int {
        lock.lock(); defer { lock.unlock() }
        return mainThreadReads
    }
}
