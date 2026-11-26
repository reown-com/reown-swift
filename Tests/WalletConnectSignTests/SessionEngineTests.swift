import XCTest
import Combine
@testable import WalletConnectSign
@testable import WalletConnectVerify
@testable import WalletConnectUtils
@testable import TestingUtils

final class SessionEngineTests: XCTestCase {

    var networkingInteractor: NetworkingInteractorMock!
    var sessionStorage: WCSessionStorageMock!
    var verifyContextStore: CodableStore<VerifyContext>!
    var verifyClient: SessionEngineVerifyClientMock!
    var rpcHistory: RPCHistory!
    var engine: SessionEngine!
    var publishers = Set<AnyCancellable>()

    override func setUp() {
        networkingInteractor = NetworkingInteractorMock()
        sessionStorage = WCSessionStorageMock()
        let defaults = RuntimeKeyValueStorage()
        rpcHistory = RPCHistory(
            keyValueStore: .init(
                defaults: defaults,
                identifier: ""
            )
        )
        verifyContextStore = CodableStore<VerifyContext>(defaults: RuntimeKeyValueStorage(), identifier: "")
        let historyService = HistoryService(
            history: rpcHistory,
            verifyContextStore: verifyContextStore
        )
        verifyClient = SessionEngineVerifyClientMock()
        engine = SessionEngine(
            networkingInteractor: networkingInteractor,
            historyService: historyService,
            verifyContextStore: verifyContextStore,
            verifyClient: verifyClient,
            kms: KeyManagementServiceMock(),
            sessionStore: sessionStorage,
            logger: ConsoleLoggerMock(),
            sessionRequestsProvider: SessionRequestsProvider(
                historyService: historyService),
            invalidRequestsSanitiser: InvalidRequestsSanitiser(historyService: historyService, history: rpcHistory)
        )
    }

    func testErrorOnRequestExpiry() {
        let expectation = expectation(description: "TestErrorOnRequestExpiry")

        sessionStorage.setSession(WCSession.stub(
            topic: "topic",
            namespaces: SessionNamespace.stubDictionary()
        ))

        networkingInteractor.onRespondError = { code in
            XCTAssertEqual(code, 8000)
            expectation.fulfill()
        }

        let request = RPCRequest.stubRequest(
            method: "method",
            chainId: Blockchain("eip155:1")!,
            expiry: UInt64(Date().timeIntervalSince1970)
        )

        networkingInteractor.requestPublisherSubject.send(("topic", request, Data(), Date(), "", "", nil))

        wait(for: [expectation], timeout: 0.5)
    }
    
    func testRemovePendingRequestsOnSessionExpiration() {
        let expectation = expectation(
            description: "Remove pending requests on session expiration"
        )
        
        let historyService = MockHistoryService()
        
        engine = SessionEngine(
            networkingInteractor: networkingInteractor,
            historyService: historyService,
            verifyContextStore: verifyContextStore,
            verifyClient: verifyClient,
            kms: KeyManagementServiceMock(),
            sessionStore: sessionStorage,
            logger: ConsoleLoggerMock(),
            sessionRequestsProvider: SessionRequestsProvider(
                historyService: historyService),
            invalidRequestsSanitiser: InvalidRequestsSanitiser(
                historyService: historyService,
                history: rpcHistory
            )
        )
        
        let expectedTopic = "topic"

        let session = WCSession.stub(
            topic: expectedTopic,
            namespaces: SessionNamespace.stubDictionary()
        )
        
        sessionStorage.setSession(session)
        
        historyService.removePendingRequestCalled = { topic in
            XCTAssertEqual(topic, expectedTopic)
            expectation.fulfill()
        }
        
        sessionStorage.onSessionExpiration!(session)

        wait(for: [expectation], timeout: 0.5)
    }

    func testReResolvesVerifyContextOnEachSessionRequest() {
        let expectation = expectation(description: "Verify context is resolved per session request")

        sessionStorage.setSession(WCSession.stub(
            topic: "topic",
            namespaces: SessionNamespace.stubDictionary()
        ))

        // A distinctive context the verify client returns for this request,
        // different from the unknown context stored on the session at proposal.
        let resolvedContext = VerifyContext(origin: "resolved.example.com", validation: .scam)
        verifyClient.contextToReturn = resolvedContext

        let request = RPCRequest.stubRequest(
            method: "method",
            chainId: Blockchain("eip155:1")!,
            expiry: UInt64(Date().timeIntervalSince1970) + 1000
        )
        let requestId = request.id!.string

        var verifyWasCalled = false
        verifyClient.onVerify = {
            verifyWasCalled = true
        }

        networkingInteractor.requestPublisherSubject.send(("topic", request, Data(), Date(), "", "", nil))

        // The verify context is resolved and stored asynchronously; poll until it lands.
        var storedContext: VerifyContext?
        func pollForStoredContext() {
            if let context = try? verifyContextStore.get(key: requestId) {
                storedContext = context
                expectation.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { pollForStoredContext() }
            }
        }
        pollForStoredContext()

        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(verifyWasCalled)
        XCTAssertEqual(storedContext, resolvedContext)
    }
}

final class SessionEngineVerifyClientMock: VerifyClientProtocol {
    var contextToReturn = VerifyContext(origin: "resolved.example.com", validation: .scam)
    var onVerify: (() -> Void)?

    func verify(_: VerificationType) async throws -> VerifyResponse {
        onVerify?()
        return VerifyResponse(origin: contextToReturn.origin, isScam: true, isVerified: false)
    }

    func createVerifyContext(origin _: String?, domain _: String, isScam _: Bool?, isVerified _: Bool?) -> VerifyContext {
        return contextToReturn
    }

    func createVerifyContextForLinkMode(redirectUniversalLink _: String, domain _: String) -> VerifyContext {
        return VerifyContext(origin: "", validation: .unknown)
    }
}
