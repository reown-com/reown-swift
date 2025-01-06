import XCTest
import WalletConnectUtils
import JSONRPC
@testable import WalletConnectKMS
@testable import WalletConnectSign
@testable import WalletConnectRelay
@testable import WalletConnectUtils
import WalletConnectPairing
import WalletConnectNetworking
import Combine

final class SignClientTests: XCTestCase {
    var dapp: SignClient!
    var dappPairingClient: PairingClient!
    var wallet: SignClient!
    var walletPairingClient: PairingClient!
    var dappKeyValueStorage: RuntimeKeyValueStorage!
    var dappRelayClient: RelayClient!
    var walletRelayClient: RelayClient!
    private var publishers = Set<AnyCancellable>()
    let walletAccount = Account(chainIdentifier: "eip155:1", address: "0x724d0D2DaD3fbB0C168f947B87Fa5DBe36F1A8bf")!
    let prvKey = Data(hex: "462c1dad6832d7d96ccf87bd6a686a4110e114aaaebd5512e552c0e3a87b480f")
    let eip1271Signature = "0xdeaddeaddead4095116db01baaf276361efd3a73c28cf8cc28dabefa945b8d536011289ac0a3b048600c1e692ff173ca944246cf7ceb319ac2262d27b395c82b1c"
    let walletLinkModeUniversalLink = "https://test"

    static private func makeClients(name: String, linkModeUniversalLink: String? = "https://x.com", supportLinkMode: Bool = false) -> (PairingClient, SignClient, RuntimeKeyValueStorage, RelayClient) {
        let loggingLevel: LoggingLevel = .debug
        let logger = ConsoleLogger(prefix: name, loggingLevel: loggingLevel)
        let keychain = KeychainStorageMock()
        let keyValueStorage = RuntimeKeyValueStorage()
        let relayClient = RelayClientFactory.create(
            relayHost: InputConfig.relayHost,
            projectId: InputConfig.projectId,
            keyValueStorage: keyValueStorage,
            keychainStorage: keychain,
            socketFactory: DefaultSocketFactory(),
            networkMonitor: NetworkMonitor(),
            logger: logger
        )

        let networkingClient = NetworkingClientFactory.create(
            relayClient: relayClient,
            logger: logger,
            keychainStorage: keychain,
            keyValueStorage: keyValueStorage
        )
        let pairingClient = PairingClientFactory.create(
            logger: logger,
            keyValueStorage: keyValueStorage,
            keychainStorage: keychain,
            networkingClient: networkingClient,
            eventsClient: MockEventsClient()
        )
        let metadata = AppMetadata(
            name: name,
            description: "",
            url: "",
            icons: [""],
            redirect: try! AppMetadata.Redirect(native: "", universal: linkModeUniversalLink, linkMode: supportLinkMode)
        )

        let client = SignClientFactory.create(
            metadata: metadata,
            logger: ConsoleLogger(prefix: "\(name) 📜", loggingLevel: loggingLevel),
            keyValueStorage: keyValueStorage,
            keychainStorage: keychain,
            pairingClient: pairingClient,
            networkingClient: networkingClient,
            iatProvider: IATProviderMock(),
            projectId: InputConfig.projectId,
            crypto: DefaultCryptoProvider(),
            eventsClient: MockEventsClient()
        )

        let clientId = try! networkingClient.getClientId()
        logger.debug("My client id is: \(clientId)")

        return (pairingClient, client, keyValueStorage, relayClient)
    }

    override func setUp() async throws {
        (dappPairingClient, dapp, dappKeyValueStorage, dappRelayClient) = Self.makeClients(name: "🍏Dapp")
        (walletPairingClient, wallet, _, walletRelayClient) = Self.makeClients(name: "🍎Wallet", linkModeUniversalLink: walletLinkModeUniversalLink)
    }

    func setUpDappForLinkMode() async throws {
        try await tearDown()
        (dappPairingClient, dapp, dappKeyValueStorage, dappRelayClient) = Self.makeClients(name: "🍏Dapp", supportLinkMode: true)
        (walletPairingClient, wallet, _, walletRelayClient) = Self.makeClients(name: "🍎Wallet", linkModeUniversalLink: walletLinkModeUniversalLink, supportLinkMode: true)
    }

    override func tearDown() {
        dapp = nil
        wallet = nil
        super.tearDown()
    }

    // MARK: - TESTS

    func testSessionPropose() async throws {
        print("🧪TEST: Starting testSessionPropose()")

        print("🧪TEST: Step 1 - Creating expectations for dapp & wallet session settle...")
        let dappSettlementExpectation = expectation(description: "Dapp expects to settle a session")
        let walletSettlementExpectation = expectation(description: "Wallet expects to settle a session")
        print("🧪TEST: Created dappSettlementExpectation & walletSettlementExpectation")

        print("🧪TEST: Step 2 - Preparing required namespaces")
        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)
        print("🧪TEST: requiredNamespaces = \(requiredNamespaces)")
        print("🧪TEST: sessionNamespaces = \(sessionNamespaces)")

        print("🧪TEST: Step 3 - Subscribing to wallet.sessionProposalPublisher...")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            print("🧪TEST: Wallet received a session proposal with id: \(proposal.id). Approving with sessionNamespaces.")
            Task(priority: .high) {
                do {
                    _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                    print("🧪TEST: Wallet approved session proposal. ID: \(proposal.id)")
                } catch {
                    XCTFail("🧪TEST: Wallet failed to approve session proposal: \(error)")
                }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Subscribing to dapp.sessionSettlePublisher...")
        dapp.sessionSettlePublisher.sink { settledSession in
            print("🧪TEST: Dapp's sessionSettlePublisher triggered. Session topic: \(settledSession.topic)")
            dappSettlementExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Subscribing to wallet.sessionSettlePublisher...")
        wallet.sessionSettlePublisher.sink { settledSession in
            print("🧪TEST: Wallet's sessionSettlePublisher triggered. Session topic: \(settledSession.topic)")
            walletSettlementExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 6 - Dapp connects with required namespaces...")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        print("🧪TEST: Dapp.connect(...) returned URI: \(uri)")

        print("🧪TEST: Step 7 - Wallet pairing with the URI returned by dapp...")
        try await walletPairingClient.pair(uri: uri)
        print("🧪TEST: Wallet pairing complete.")

        print("🧪TEST: Step 8 - Waiting for session to settle on both dapp and wallet...")
        await fulfillment(of: [dappSettlementExpectation, walletSettlementExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionPropose() ✅")
    }

    func testSessionReject() async throws {
        print("🧪TEST: Starting testSessionReject()")

        print("🧪TEST: Step 1 - Creating expectation for session rejection")
        let sessionRejectExpectation = expectation(description: "Proposer is notified on session rejection")

        print("🧪TEST: Step 2 - Stub required namespaces")
        let requiredNamespaces = ProposalNamespace.stubRequired()

        class Store { var rejectedProposal: Session.Proposal? }
        let store = Store()
        let semaphore = DispatchSemaphore(value: 0)

        print("🧪TEST: Step 3 - Dapp connects with required namespaces")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        print("🧪TEST: Step 4 - Wallet pairing with the URI")
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 5 - Wallet listening to sessionProposalPublisher...")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            print("🧪TEST: Wallet received a session proposal with id: \(proposal.id). Rejecting it.")
            Task(priority: .high) {
                do {
                    try await wallet.rejectSession(proposalId: proposal.id, reason: .unsupportedChains)
                    store.rejectedProposal = proposal
                    semaphore.signal()
                } catch {
                    XCTFail("🧪TEST: Failed to reject session: \(error)")
                }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 6 - Dapp listens for session rejection")
        dapp.sessionRejectionPublisher.sink { proposal, _ in
            print("🧪TEST: Dapp received session rejection for proposal with id: \(proposal.id)")
            semaphore.wait()
            XCTAssertEqual(store.rejectedProposal, proposal)
            sessionRejectExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 7 - Waiting for sessionRejectExpectation...")
        await fulfillment(of: [sessionRejectExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionReject() ✅")
    }

    func testSessionDelete() async throws {
        print("🧪TEST: Starting testSessionDelete()")

        print("🧪TEST: Step 1 - Creating expectation for session delete")
        let sessionDeleteExpectation = expectation(description: "Wallet expects session to be deleted")
        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)

        print("🧪TEST: Step 2 - Wallet listens for session proposals and approves them")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            print("🧪TEST: Wallet received proposal with id: \(proposal.id). Approving.")
            Task(priority: .high) {
                do {
                    _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                    print("🧪TEST: Wallet approved session proposal: \(proposal.id)")
                } catch {
                    XCTFail("🧪TEST: Wallet failed to approve: \(error)")
                }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for session settle and then disconnects")
        dapp.sessionSettlePublisher.sink { [unowned self] settledSession in
            print("🧪TEST: Dapp sees session settle. Disconnecting session topic: \(settledSession.topic)")
            Task(priority: .high) {
                try await dapp.disconnect(topic: settledSession.topic)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Wallet listens for session delete")
        wallet.sessionDeletePublisher.sink { _ in
            print("🧪TEST: Wallet sessionDeletePublisher triggered.")
            sessionDeleteExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp connects with required namespaces, and wallet pairs")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 6 - Waiting for sessionDeleteExpectation...")
        await fulfillment(of: [sessionDeleteExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionDelete() ✅")
    }

    func testSessionPing() async throws {
        print("🧪TEST: Starting testSessionPing()")

        print("🧪TEST: Step 1 - Creating expectation for ping response")
        let expectation = expectation(description: "Proposer receives ping response")

        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)

        print("🧪TEST: Step 2 - Wallet listens for session proposals and approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            print("🧪TEST: Wallet received proposal with id: \(proposal.id). Approving.")
            Task(priority: .high) {
                try! await self.wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for session settle then pings")
        dapp.sessionSettlePublisher.sink { [unowned self] settledSession in
            print("🧪TEST: Dapp sees session settle. Pinging session topic: \(settledSession.topic)")
            Task(priority: .high) {
                try! await dapp.ping(topic: settledSession.topic)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp listens for pingResponsePublisher")
        dapp.pingResponsePublisher.sink { topic in
            let session = self.wallet.getSessions().first!
            XCTAssertEqual(topic, session.topic)
            print("🧪TEST: Dapp pingResponsePublisher triggered. Topic: \(topic)")
            expectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp connects with required namespaces, wallet pairs")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 6 - Waiting for ping response expectation...")
        await fulfillment(of: [expectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionPing() ✅")
    }

    func testSessionRequest() async throws {
        print("🧪TEST: Starting testSessionRequest()")

        let requestExpectation = expectation(description: "Wallet expects to receive a request")
        let responseExpectation = expectation(description: "Dapp expects to receive a response")
        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)

        let requestMethod = "eth_sendTransaction"
        let requestParams = [EthSendTransaction.stub()]
        let responseParams = "0xdeadbeef"
        let chain = Blockchain("eip155:1")!

        // sleep is needed as emitRequestIfPending() will be called on client init
        // then on request itself; second request would be debounced
        sleep(1)

        print("🧪TEST: Step 1 - Wallet listens for session proposals and approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            print("🧪TEST: Wallet received proposal with id: \(proposal.id). Approving.")
            Task(priority: .high) {
                do {
                    _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                    print("🧪TEST: Wallet approved session proposal: \(proposal.id)")
                } catch {
                    XCTFail("🧪TEST: Approve error: \(error)")
                }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for session settle then sends a request")
        dapp.sessionSettlePublisher.sink { [unowned self] settledSession in
            print("🧪TEST: Dapp sees session settle. Sending session request with method: \(requestMethod)")
            Task(priority: .high) {
                let request = try! Request(id: RPCID(0), topic: settledSession.topic, method: requestMethod, params: requestParams, chainId: chain)
                try await dapp.request(params: request)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Wallet listens for sessionRequestPublisher to handle incoming request")
        wallet.sessionRequestPublisher.sink { [unowned self] (sessionRequest, _) in
            print("🧪TEST: Wallet received a session request with method: \(sessionRequest.method)")
            let receivedParams = try! sessionRequest.params.get([EthSendTransaction].self)
            XCTAssertEqual(receivedParams, requestParams)
            XCTAssertEqual(sessionRequest.method, requestMethod)
            requestExpectation.fulfill()
            Task(priority: .high) {
                try await wallet.respond(topic: sessionRequest.topic, requestId: sessionRequest.id, response: .response(AnyCodable(responseParams)))
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp listens for sessionResponsePublisher")
        dapp.sessionResponsePublisher.sink { response in
            switch response.result {
            case .response(let resp):
                XCTAssertEqual(try! resp.get(String.self), responseParams)
            case .error:
                XCTFail("🧪TEST: Received error instead of response")
            }
            responseExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp connects, wallet pairs")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 6 - Waiting for request & response expectations...")
        await fulfillment(of: [requestExpectation, responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionRequest() ✅")
    }

    func testSessionRequestFailureResponse() async throws {
        print("🧪TEST: Starting testSessionRequestFailureResponse()")

        let expectation = expectation(description: "Dapp expects to receive an error response")
        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)

        let requestMethod = "eth_sendTransaction"
        let requestParams = [EthSendTransaction.stub()]
        let error = JSONRPCError(code: 0, message: "error")
        let chain = Blockchain("eip155:1")!

        // sleep is needed as emitRequestIfPending() will be called on client init
        // then on request itself; second request would be debounced
        sleep(1)

        print("🧪TEST: Step 1 - Wallet listens for session proposals & approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            print("🧪TEST: Wallet received a proposal with id: \(proposal.id). Approving.")
            Task(priority: .high) {
                try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for session settle & sends a request")
        dapp.sessionSettlePublisher.sink { [unowned self] settledSession in
            print("🧪TEST: Dapp sees session settle. Sending a request with method: \(requestMethod)")
            Task(priority: .high) {
                let req = try! Request(id: RPCID(0), topic: settledSession.topic, method: requestMethod, params: requestParams, chainId: chain)
                try await dapp.request(params: req)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Wallet listens for sessionRequestPublisher, responds with error")
        wallet.sessionRequestPublisher.sink { [unowned self] (sessionRequest, _) in
            Task(priority: .high) {
                try await wallet.respond(topic: sessionRequest.topic, requestId: sessionRequest.id, response: .error(error))
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp listens for sessionResponsePublisher and expects an error")
        dapp.sessionResponsePublisher.sink { response in
            switch response.result {
            case .response:
                XCTFail("🧪TEST: Expected error but got response")
            case .error(let receivedError):
                XCTAssertEqual(error, receivedError)
            }
            expectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp connects, wallet pairs")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 6 - Waiting for the error expectation...")
        await fulfillment(of: [expectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionRequestFailureResponse() ✅")
    }

    func testSuccessfulSessionUpdateNamespaces() async throws {
        print("🧪TEST: Starting testSuccessfulSessionUpdateNamespaces()")

        let expectation = expectation(description: "Dapp updates namespaces")
        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)

        print("🧪TEST: Step 1 - Wallet listens for session proposals & approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for session settle & triggers update")
        dapp.sessionSettlePublisher.sink { [unowned self] settledSession in
            Task(priority: .high) {
                let updateNamespace = SessionNamespace.make(
                    toRespond: ProposalNamespace.stubRequired(chains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!])
                )
                try! await wallet.update(topic: settledSession.topic, namespaces: updateNamespace)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for sessionUpdatePublisher")
        dapp.sessionUpdatePublisher.sink { _, namespace in
            XCTAssertEqual(namespace.values.first?.accounts.count, 2)
            expectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp connects, wallet pairs")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 5 - Waiting for update expectation...")
        await fulfillment(of: [expectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSuccessfulSessionUpdateNamespaces() ✅")
    }

    func testSuccessfulSessionExtend() async throws {
        print("🧪TEST: Starting testSuccessfulSessionExtend()")

        let expectation = expectation(description: "Dapp extends session")
        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)

        print("🧪TEST: Step 1 - Wallet approves session proposals")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for sessionExtendPublisher")
        dapp.sessionExtendPublisher.sink { _, _ in
            expectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for session settle and extends session")
        dapp.sessionSettlePublisher.sink { [unowned self] settledSession in
            Task(priority: .high) {
                try! await wallet.extend(topic: settledSession.topic)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp connects, wallet pairs")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 5 - Waiting for extend expectation...")
        await fulfillment(of: [expectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSuccessfulSessionExtend() ✅")
    }

    func testSessionEventSucceeds() async throws {
        print("🧪TEST: Starting testSessionEventSucceeds()")

        let expectation = expectation(description: "Dapp receives session event")

        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)
        let event = Session.Event(name: "any", data: AnyCodable("event_data"))
        let chain = Blockchain("eip155:1")!

        print("🧪TEST: Step 1 - Wallet listens for proposals & approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for sessionEventPublisher")
        dapp.sessionEventPublisher.sink { _, _, _ in
            expectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for session settle then emits event")
        dapp.sessionSettlePublisher.sink { [unowned self] settledSession in
            Task(priority: .high) {
                try! await wallet.emit(topic: settledSession.topic, event: event, chainId: chain)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Connect & Pair")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 5 - Waiting for session event expectation...")
        await fulfillment(of: [expectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionEventSucceeds() ✅")
    }

    func testSessionEventFails() async throws {
        print("🧪TEST: Starting testSessionEventFails()")

        let expectation = expectation(description: "Dapp receives session event")

        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)
        let event = Session.Event(name: "unknown", data: AnyCodable("event_data"))
        let chain = Blockchain("eip155:1")!

        print("🧪TEST: Step 1 - Wallet listens for proposals & approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for session settle then tries to emit event with unknown name")
        dapp.sessionSettlePublisher.sink { [unowned self] settledSession in
            Task(priority: .high) {
                await XCTAssertThrowsErrorAsync(try await wallet.emit(topic: settledSession.topic, event: event, chainId: chain))
                expectation.fulfill()
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Connect & Pair")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 4 - Waiting for expectation (we expect an error to be thrown) ...")
        await fulfillment(of: [expectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionEventFails() ✅")
    }

    func testCaip25SatisfyAllRequiredAllOptionalNamespacesSuccessful() async throws {
        print("🧪TEST: Starting testCaip25SatisfyAllRequiredAllOptionalNamespacesSuccessful()")

        let dappSettlementExpectation = expectation(description: "Dapp expects to settle a session")
        let walletSettlementExpectation = expectation(description: "Wallet expects to settle a session")

        print("🧪TEST: Step 1 - Prepare required and optional namespaces")
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155:1": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            ),
            "eip155": ProposalNamespace(
                chains: [Blockchain("eip155:137")!, Blockchain("eip155:1")!],
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155:5": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            ),
            "solana": ProposalNamespace(
                chains: [Blockchain("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")!],
                methods: ["solana_signMessage"],
                events: ["any"]
            )
        ]

        print("🧪TEST: Step 2 - Build session proposal object")
        let sessionProposal = Session.Proposal(
            id: "",
            pairingTopic: "",
            proposer: AppMetadata.stub(),
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces,
            sessionProperties: nil,
            proposal: SessionProposal(relays: [], proposer: Participant(publicKey: "", metadata: AppMetadata.stub()), requiredNamespaces: [:], optionalNamespaces: [:], sessionProperties: [:])
        )

        print("🧪TEST: Step 3 - Build auto session namespaces")
        let sessionNamespaces = try AutoNamespaces.build(
            sessionProposal: sessionProposal,
            chains: [
                Blockchain("eip155:137")!,
                Blockchain("eip155:1")!,
                Blockchain("eip155:5")!,
                Blockchain("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")!
            ],
            methods: ["personal_sign", "eth_sendTransaction", "solana_signMessage"],
            events: ["any"],
            accounts: [
                Account(blockchain: Blockchain("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")!, address: "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")!,
                Account(blockchain: Blockchain("eip155:1")!, address: "0x00")!,
                Account(blockchain: Blockchain("eip155:137")!, address: "0x00")!,
                Account(blockchain: Blockchain("eip155:5")!, address: "0x00")!
            ]
        )

        print("🧪TEST: Step 4 - Wallet listens for session proposals and approves with built namespaces")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                do {
                    _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                } catch {
                    XCTFail("\(error)")
                }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp & Wallet both listen for session settle")
        dapp.sessionSettlePublisher.sink { settledSession in
            dappSettlementExpectation.fulfill()
        }.store(in: &publishers)
        wallet.sessionSettlePublisher.sink { _ in
            walletSettlementExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 6 - Dapp connects with required + optional, wallet pairs")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces, optionalNamespaces: optionalNamespaces)
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 7 - Waiting for both settle expectations...")
        await fulfillment(of: [dappSettlementExpectation, walletSettlementExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testCaip25SatisfyAllRequiredAllOptionalNamespacesSuccessful() ✅")
    }

    func testCaip25SatisfyAllRequiredNamespacesSuccessful() async throws {
        print("🧪TEST: Starting testCaip25SatisfyAllRequiredNamespacesSuccessful()")

        let dappSettlementExpectation = expectation(description: "Dapp expects to settle a session")
        let walletSettlementExpectation = expectation(description: "Wallet expects to settle a session")

        print("🧪TEST: Step 1 - Prepare required & optional namespaces")
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155:1": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            ),
            "eip155": ProposalNamespace(
                chains: [Blockchain("eip155:137")!],
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155:5": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            )
        ]

        print("🧪TEST: Step 2 - Build session proposal object")
        let sessionProposal = Session.Proposal(
            id: "",
            pairingTopic: "",
            proposer: AppMetadata.stub(),
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces,
            sessionProperties: nil,
            proposal: SessionProposal(relays: [], proposer: Participant(publicKey: "", metadata: AppMetadata.stub()), requiredNamespaces: [:], optionalNamespaces: [:], sessionProperties: [:])
        )

        print("🧪TEST: Step 3 - Build auto session namespaces")
        let sessionNamespaces = try AutoNamespaces.build(
            sessionProposal: sessionProposal,
            chains: [
                Blockchain("eip155:137")!,
                Blockchain("eip155:1")!
            ],
            methods: ["personal_sign", "eth_sendTransaction"],
            events: ["any"],
            accounts: [
                Account(blockchain: Blockchain("eip155:1")!, address: "0x00")!,
                Account(blockchain: Blockchain("eip155:137")!, address: "0x00")!
            ]
        )

        print("🧪TEST: Step 4 - Wallet listens for session proposals & approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                do {
                    _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                } catch {
                    XCTFail("\(error)")
                }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp & Wallet both wait for sessionSettle")
        dapp.sessionSettlePublisher.sink { _ in
            dappSettlementExpectation.fulfill()
        }.store(in: &publishers)
        wallet.sessionSettlePublisher.sink { _ in
            walletSettlementExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 6 - Dapp connects, wallet pairs, wait for settle")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces, optionalNamespaces: optionalNamespaces)
        try await walletPairingClient.pair(uri: uri)
        await fulfillment(of: [dappSettlementExpectation, walletSettlementExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testCaip25SatisfyAllRequiredNamespacesSuccessful() ✅")
    }

    func testCaip25SatisfyEmptyRequiredNamespacesExtraOptionalNamespacesSuccessful() async throws {
        print("🧪TEST: Starting testCaip25SatisfyEmptyRequiredNamespacesExtraOptionalNamespacesSuccessful()")

        let dappSettlementExpectation = expectation(description: "Dapp expects to settle a session")
        let walletSettlementExpectation = expectation(description: "Wallet expects to settle a session")

        print("🧪TEST: Step 1 - Prepare required & optional namespaces (required empty)")
        let requiredNamespaces: [String: ProposalNamespace] = [:]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155:5": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            )
        ]

        print("🧪TEST: Step 2 - Build session proposal object")
        let sessionProposal = Session.Proposal(
            id: "",
            pairingTopic: "",
            proposer: AppMetadata.stub(),
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces,
            sessionProperties: nil,
            proposal: SessionProposal(relays: [], proposer: Participant(publicKey: "", metadata: AppMetadata.stub()), requiredNamespaces: [:], optionalNamespaces: [:], sessionProperties: [:])
        )

        print("🧪TEST: Step 3 - Build auto session namespaces")
        let sessionNamespaces = try AutoNamespaces.build(
            sessionProposal: sessionProposal,
            chains: [
                Blockchain("eip155:1")!,
                Blockchain("eip155:5")!
            ],
            methods: ["personal_sign", "eth_sendTransaction"],
            events: ["any"],
            accounts: [
                Account(blockchain: Blockchain("eip155:1")!, address: "0x00")!,
                Account(blockchain: Blockchain("eip155:5")!, address: "0x00")!
            ]
        )

        print("🧪TEST: Step 4 - Wallet listens for session proposals & approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                do {
                    _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                } catch {
                    XCTFail("\(error)")
                }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp & Wallet both wait for sessionSettle")
        dapp.sessionSettlePublisher.sink { _ in
            dappSettlementExpectation.fulfill()
        }.store(in: &publishers)
        wallet.sessionSettlePublisher.sink { _ in
            walletSettlementExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 6 - Dapp connects, wallet pairs, wait for settle")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces, optionalNamespaces: optionalNamespaces)
        try await walletPairingClient.pair(uri: uri)
        await fulfillment(of: [dappSettlementExpectation, walletSettlementExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testCaip25SatisfyEmptyRequiredNamespacesExtraOptionalNamespacesSuccessful() ✅")
    }

    func testCaip25SatisfyPartiallyRequiredNamespacesFails() async throws {
        print("🧪TEST: Starting testCaip25SatisfyPartiallyRequiredNamespacesFails()")

        let settlementFailedExpectation = expectation(description: "Dapp fails to settle a session")

        print("🧪TEST: Step 1 - Prepare required & optional namespaces (some missing in chain list)")
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155:1": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            ),
            "eip155:137": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155:5": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            )
        ]

        let sessionProposal = Session.Proposal(
            id: "",
            pairingTopic: "",
            proposer: AppMetadata.stub(),
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces,
            sessionProperties: nil,
            proposal: SessionProposal(relays: [], proposer: Participant(publicKey: "", metadata: AppMetadata.stub()), requiredNamespaces: [:], optionalNamespaces: [:], sessionProperties: [:])
        )

        print("🧪TEST: Step 2 - Attempt to build auto namespaces with missing chain")
        do {
            let sessionNamespaces = try AutoNamespaces.build(
                sessionProposal: sessionProposal,
                chains: [
                    Blockchain("eip155:1")!
                ],
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"],
                accounts: [
                    Account(blockchain: Blockchain("eip155:1")!, address: "0x00")!
                ]
            )

            print("🧪TEST: Step 3 - Wallet listens for session proposal & tries to approve with incomplete sessionNamespaces")
            wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
                Task(priority: .high) {
                    do {
                        _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                    } catch {
                        settlementFailedExpectation.fulfill()
                    }
                }
            }.store(in: &publishers)
        } catch {
            settlementFailedExpectation.fulfill()
        }

        print("🧪TEST: Step 4 - Connect & pair, expecting settlement failure")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces, optionalNamespaces: optionalNamespaces)
        try await walletPairingClient.pair(uri: uri)
        await fulfillment(of: [settlementFailedExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testCaip25SatisfyPartiallyRequiredNamespacesFails() ✅")
    }

    func testCaip25SatisfyPartiallyRequiredNamespacesMethodsFails() async throws {
        print("🧪TEST: Starting testCaip25SatisfyPartiallyRequiredNamespacesMethodsFails()")

        let settlementFailedExpectation = expectation(description: "Dapp fails to settle a session")

        print("🧪TEST: Step 1 - Prepare required & optional namespaces (missing some methods)")
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155:1": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            ),
            "eip155": ProposalNamespace(
                chains: [Blockchain("eip155:137")!],
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155:5": ProposalNamespace(
                methods: ["personal_sign", "eth_sendTransaction"],
                events: ["any"]
            )
        ]

        let sessionProposal = Session.Proposal(
            id: "",
            pairingTopic: "",
            proposer: AppMetadata.stub(),
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces,
            sessionProperties: nil,
            proposal: SessionProposal(relays: [], proposer: Participant(publicKey: "", metadata: AppMetadata.stub()), requiredNamespaces: [:], optionalNamespaces: [:], sessionProperties: [:])
        )

        print("🧪TEST: Step 2 - Attempt to build auto namespaces with missing method (we only pass personal_sign, skipping eth_sendTransaction)")
        do {
            let sessionNamespaces = try AutoNamespaces.build(
                sessionProposal: sessionProposal,
                chains: [
                    Blockchain("eip155:1")!,
                    Blockchain("eip155:137")!
                ],
                methods: ["personal_sign"], // Missing 'eth_sendTransaction'
                events: ["any"],
                accounts: [
                    Account(blockchain: Blockchain("eip155:1")!, address: "0x00")!,
                    Account(blockchain: Blockchain("eip155:137")!, address: "0x00")!
                ]
            )

            wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
                Task(priority: .high) {
                    do {
                        _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                    } catch {
                        settlementFailedExpectation.fulfill()
                    }
                }
            }.store(in: &publishers)
        } catch {
            settlementFailedExpectation.fulfill()
        }

        print("🧪TEST: Step 3 - Connect & pair, expecting settlement failure")
        let uri = try! await dapp.connect(requiredNamespaces: requiredNamespaces, optionalNamespaces: optionalNamespaces)
        try await walletPairingClient.pair(uri: uri)
        await fulfillment(of: [settlementFailedExpectation], timeout: 1)

        print("🧪TEST: Finished testCaip25SatisfyPartiallyRequiredNamespacesMethodsFails() ✅")
    }

    func testEIP191SessionAuthenticated() async throws {
        print("🧪TEST: Starting testEIP191SessionAuthenticated()")

        let responseExpectation = expectation(description: "successful response delivered")

        print("🧪TEST: Step 1 - Wallet listens for authenticateRequestPublisher and approves with eip191")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            Task(priority: .high) {
                let signerFactory = DefaultSignerFactory()
                let signer = MessageSignerFactory(signerFactory: signerFactory).create()

                let supportedAuthPayload = try! wallet.buildAuthPayload(
                    payload: request.payload,
                    supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                    supportedMethods: ["eth_signTransaction", "personal_sign"]
                )
                let siweMessage = try! wallet.formatAuthMessage(payload: supportedAuthPayload, account: walletAccount)
                let signature = try! signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                let auth = try! wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: walletAccount)
                _ = try! await wallet.approveSessionAuthenticate(requestId: request.id, auths: [auth])
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for authResponsePublisher success")
        dapp.authResponsePublisher.sink { (_, result) in
            guard case .success = result else { XCTFail(); return }
            responseExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp calls authenticate with stub, wallet pairs, wait for response")
        let uri = try await dapp.authenticate(AuthRequestParams.stub())!
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 4 - Wait for response expectation...")
        await fulfillment(of: [responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testEIP191SessionAuthenticated() ✅")
    }

    func testEIP191SessionAuthenticateEmptyMethods() async throws {
        print("🧪TEST: Starting testEIP191SessionAuthenticateEmptyMethods()")

        let responseExpectation = expectation(description: "successful response delivered")

        print("🧪TEST: Step 1 - Wallet listens for eip191 but with no specified methods")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            Task(priority: .high) {
                let signerFactory = DefaultSignerFactory()
                let signer = MessageSignerFactory(signerFactory: signerFactory).create()

                let supportedAuthPayload = try! wallet.buildAuthPayload(
                    payload: request.payload,
                    supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                    supportedMethods: ["eth_signTransaction", "personal_sign"]
                )
                let siweMessage = try! wallet.formatAuthMessage(payload: supportedAuthPayload, account: walletAccount)
                let signature = try! signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                let auth = try! wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: walletAccount)
                _ = try! await wallet.approveSessionAuthenticate(requestId: request.id, auths: [auth])
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for authResponsePublisher success")
        dapp.authResponsePublisher.sink { (_, result) in
            guard case .success = result else { XCTFail(); return }
            responseExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp calls authenticate with nil methods")
        let uri = try await dapp.authenticate(AuthRequestParams.stub(methods: nil))!
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 4 - Wait for response expectation")
        await fulfillment(of: [responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testEIP191SessionAuthenticateEmptyMethods() ✅")
    }

    func testEIP191SessionAuthenticatedMultiCacao() async throws {
        print("🧪TEST: Starting testEIP191SessionAuthenticatedMultiCacao()")

        let responseExpectation = expectation(description: "successful response delivered")

        print("🧪TEST: Step 1 - Wallet listens for authenticateRequestPublisher, sends multiple cacaos for eip155:1 & eip155:137")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            Task(priority: .high) {
                let signerFactory = DefaultSignerFactory()
                let signer = MessageSignerFactory(signerFactory: signerFactory).create()

                var cacaos = [Cacao]()
                request.payload.chains.forEach { chain in
                    let account = Account(blockchain: Blockchain(chain)!, address: walletAccount.address)!
                    let supportedAuthPayload = try! wallet.buildAuthPayload(
                        payload: request.payload,
                        supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                        supportedMethods: ["eth_sendTransaction", "personal_sign"]
                    )
                    let siweMessage = try! wallet.formatAuthMessage(payload: supportedAuthPayload, account: account)
                    let signature = try! signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                    let cacao = try! wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: account)
                    cacaos.append(cacao)
                }
                _ = try! await wallet.approveSessionAuthenticate(requestId: request.id, auths: cacaos)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for authResponsePublisher success, expects multi accounts")
        dapp.authResponsePublisher.sink { (_, result) in
            guard case .success(let (session, _)) = result,
                  let session = session else { XCTFail(); return }
            XCTAssertEqual(session.accounts.count, 2)
            XCTAssertEqual(session.namespaces["eip155"]?.methods.count, 2)
            XCTAssertEqual(session.namespaces["eip155"]?.accounts.count, 2)
            responseExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp calls authenticate with both eip155:1 and eip155:137 chains")
        let uri = try await dapp.authenticate(AuthRequestParams.stub(chains: ["eip155:1", "eip155:137"]))!
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 4 - Wait for response expectation")
        await fulfillment(of: [responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testEIP191SessionAuthenticatedMultiCacao() ✅")
    }

    func testEIP1271SessionAuthenticated() async throws {
        print("🧪TEST: Starting testEIP1271SessionAuthenticated()")

        print("🧪TEST: Step 1 - Prepare account & signature for EIP1271, plus expectation")
        let account = Account(chainIdentifier: "eip155:1", address: "0x6DF3d14554742D67068BB7294C80107a3c655A56")!
        let eip1271Signature = "0xb518b65724f224f8b12dedeeb06f8b278eb7d3b42524959bed5d0dfa49801bd776c7ee05de396eadc38ee693c917a04d93b20981d68c4a950cbc42ea7f4264bc1c"
        let responseExpectation = expectation(description: "successful response delivered")

        print("🧪TEST: Step 2 - Dapp calls dapp.authenticate(...) with EIP1271 data")
        let uri = try! await dapp.authenticate(AuthRequestParams(
            domain: "etherscan.io",
            chains: ["eip155:1"],
            nonce: "DTYxeNr95Ne7Sape5",
            uri: "https://etherscan.io/verifiedSignatures#",
            nbf: nil,
            exp: nil,
            statement: "Sign message to verify ownership of the address 0x6DF3d14554742D67068BB7294C80107a3c655A56 on etherscan.io",
            requestId: nil,
            resources: nil,
            methods: nil
        ))!
        print("🧪TEST: Dapp.authenticate(...) returned URI: \(uri)")

        print("🧪TEST: Step 3 - Wallet pairs with that URI")
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 4 - Wallet listens for authenticateRequestPublisher & approves EIP1271")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            print("🧪TEST: Wallet received authenticate request. Building EIP1271 cacao and approving...")
            Task(priority: .high) {
                let signature = CacaoSignature(t: .eip1271, s: eip1271Signature)
                let cacao = try! wallet.buildSignedAuthObject(authPayload: request.payload, signature: signature, account: account)
                _ = try await wallet.approveSessionAuthenticate(requestId: request.id, auths: [cacao])
            }
        }
        .store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp listens for authResponsePublisher success")
        dapp.authResponsePublisher.sink { (_, result) in
            guard case .success = result else { XCTFail(); return }
            responseExpectation.fulfill()
        }
        .store(in: &publishers)

        print("🧪TEST: Step 6 - Waiting for EIP1271 auth response expectation...")
        await fulfillment(of: [responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testEIP1271SessionAuthenticated() ✅")
    }

    func testEIP191SessionAuthenticateSignatureVerificationFailed() async {
        print("🧪TEST: Starting testEIP191SessionAuthenticateSignatureVerificationFailed()")

        let requestExpectation = expectation(description: "error response delivered")

        print("🧪TEST: Step 1 - Dapp calls authenticate(...), wallet pairs")
        let uri = try! await dapp.authenticate(AuthRequestParams.stub())!
        try? await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 2 - Wallet listens for authenticateRequestPublisher but uses invalid EIP1271 signature on eip191 flow")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            Task(priority: .high) {
                let invalidSignature = CacaoSignature(t: .eip1271, s: eip1271Signature)
                let supportedAuthPayload = try! wallet.buildAuthPayload(
                    payload: request.payload,
                    supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                    supportedMethods: ["eth_signTransaction", "personal_sign"]
                )
                let cacao = try! wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: invalidSignature, account: walletAccount)
                await XCTAssertThrowsErrorAsync(try await wallet.approveSessionAuthenticate(requestId: request.id, auths: [cacao]))
                requestExpectation.fulfill()
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Waiting for requestExpectation (we expect a throw)...")
        await fulfillment(of: [requestExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testEIP191SessionAuthenticateSignatureVerificationFailed() ✅")
    }

    func testSessionAuthenticateUserRespondError() async {
        print("🧪TEST: Starting testSessionAuthenticateUserRespondError()")

        let responseExpectation = expectation(description: "error response delivered")

        print("🧪TEST: Step 1 - Dapp calls authenticate(...), wallet pairs")
        let uri = try! await dapp.authenticate(AuthRequestParams.stub())!
        try? await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 2 - Wallet listens for authenticateRequestPublisher but rejects session")
        wallet.authenticateRequestPublisher.sink { [unowned self] request in
            Task(priority: .high) {
                try! await wallet.rejectSession(requestId: request.0.id)
            }
        }
        .store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for authResponsePublisher, expects .failure(.userRejeted)")
        dapp.authResponsePublisher.sink { (_, result) in
            guard case .failure(let error) = result else { XCTFail(); return }
            XCTAssertEqual(error, .userRejeted)
            responseExpectation.fulfill()
        }
        .store(in: &publishers)

        print("🧪TEST: Step 4 - Waiting for error response expectation...")
        await fulfillment(of: [responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionAuthenticateUserRespondError() ✅")
    }

    func testSessionRequestOnAuthenticatedSession() async throws {
        print("🧪TEST: Starting testSessionRequestOnAuthenticatedSession()")

        let requestExpectation = expectation(description: "Wallet expects to receive a request")
        let responseExpectation = expectation(description: "Dapp expects to receive a response")

        let requestMethod = "eth_sendTransaction"
        let requestParams = [EthSendTransaction.stub()]
        let responseParams = "0xdeadbeef"
        let chain = Blockchain("eip155:1")!
        sleep(1) // see comment above

        print("🧪TEST: Step 1 - Wallet authenticates using eip191")
        wallet.authenticateRequestPublisher
            .first()
            .sink { [unowned self] (request, _) in
                Task(priority: .high) {
                    let signerFactory = DefaultSignerFactory()
                    let signer = MessageSignerFactory(signerFactory: signerFactory).create()
                    let supportedAuthPayload = try! wallet.buildAuthPayload(
                        payload: request.payload,
                        supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                        supportedMethods: ["eth_sendTransaction", "personal_sign"]
                    )
                    let siweMessage = try! wallet.formatAuthMessage(payload: supportedAuthPayload, account: walletAccount)
                    let signature = try! signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                    let cacao = try! wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: walletAccount)
                    _ = try! await wallet.approveSessionAuthenticate(requestId: request.id, auths: [cacao])
                }
            }
            .store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for authResponsePublisher, once success, sends a session request")
        dapp.authResponsePublisher
            .first()
            .sink { [unowned self] (_, result) in
                guard case .success(let (session, _)) = result,
                      let session = session else { XCTFail(); return }
                Task(priority: .high) {
                    let request = try Request(id: RPCID(0), topic: session.topic, method: requestMethod, params: requestParams, chainId: chain)
                    try await dapp.request(params: request)
                }
            }
            .store(in: &publishers)

        print("🧪TEST: Step 3 - Wallet listens for sessionRequestPublisher, verifies request, responds")
        wallet.sessionRequestPublisher
            .first()
            .sink { [unowned self] (sessionRequest, _) in
                let receivedParams = try! sessionRequest.params.get([EthSendTransaction].self)
                XCTAssertEqual(receivedParams, requestParams)
                XCTAssertEqual(sessionRequest.method, requestMethod)
                requestExpectation.fulfill()
                Task(priority: .high) {
                    try await wallet.respond(topic: sessionRequest.topic, requestId: sessionRequest.id, response: .response(AnyCodable(responseParams)))
                }
            }
            .store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp listens for sessionResponsePublisher, expects success")
        dapp.sessionResponsePublisher
            .first()
            .sink { response in
                switch response.result {
                case .response(let resp):
                    XCTAssertEqual(try! resp.get(String.self), responseParams)
                case .error:
                    XCTFail()
                }
                responseExpectation.fulfill()
            }
            .store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp calls authenticate(...) with stub, wallet pairs")
        let uri = try await dapp.authenticate(AuthRequestParams.stub())!
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 6 - Wait for both request & response expectations")
        await fulfillment(of: [requestExpectation, responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionRequestOnAuthenticatedSession() ✅")
    }

    func testSessionRequestOnAuthenticatedSessionForAChainNotIncludedInCacao() async throws {
        print("🧪TEST: Starting testSessionRequestOnAuthenticatedSessionForAChainNotIncludedInCacao()")

        let requestExpectation = expectation(description: "Wallet expects to receive a request")
        let responseExpectation = expectation(description: "Dapp expects to receive a response")

        let requestMethod = "eth_sendTransaction"
        let requestParams = [EthSendTransaction.stub()]
        let responseParams = "0xdeadbeef"

        sleep(1)

        print("🧪TEST: Step 1 - Wallet authenticates for eip155:1 and eip155:137")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            Task(priority: .high) {
                let signerFactory = DefaultSignerFactory()
                let signer = MessageSignerFactory(signerFactory: signerFactory).create()
                let supportedAuthPayload = try! wallet.buildAuthPayload(
                    payload: request.payload,
                    supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                    supportedMethods: ["eth_sendTransaction", "personal_sign"]
                )
                let signingAccount = Account(chainIdentifier: "eip155:1", address: "0x724d0D2DaD3fbB0C168f947B87Fa5DBe36F1A8bf")!
                let siweMessage = try! wallet.formatAuthMessage(payload: supportedAuthPayload, account: signingAccount)
                let signature = try! signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                let cacao = try! wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: walletAccount)
                _ = try! await wallet.approveSessionAuthenticate(requestId: request.id, auths: [cacao])
            }
        }
        .store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for authResponse, sends request to chain eip155:137 (which is included in the cacao!)")
        dapp.authResponsePublisher.sink { [unowned self] (_, result) in
            guard case .success(let (session, _)) = result,
                let session = session else { XCTFail(); return }
            Task(priority: .high) {
                let request = try Request(id: RPCID(0), topic: session.topic, method: requestMethod, params: requestParams, chainId: Blockchain("eip155:137")!)
                try await dapp.request(params: request)
            }
        }
        .store(in: &publishers)

        print("🧪TEST: Step 3 - Wallet listens for sessionRequestPublisher, verifies request, responds")
        wallet.sessionRequestPublisher.sink { [unowned self] (sessionRequest, _) in
            let receivedParams = try! sessionRequest.params.get([EthSendTransaction].self)
            XCTAssertEqual(receivedParams, requestParams)
            XCTAssertEqual(sessionRequest.method, requestMethod)
            requestExpectation.fulfill()
            Task(priority: .high) {
                try await wallet.respond(topic: sessionRequest.topic, requestId: sessionRequest.id, response: .response(AnyCodable(responseParams)))
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp listens for sessionResponsePublisher, expects success")
        dapp.sessionResponsePublisher.sink { response in
            switch response.result {
            case .response(let resp):
                XCTAssertEqual(try! resp.get(String.self), responseParams)
            case .error:
                XCTFail()
            }
            responseExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp calls authenticate(...) specifying eip155:1 & eip155:137")
        let uri = try await dapp.authenticate(AuthRequestParams.stub(chains: ["eip155:1", "eip155:137"]))!
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 6 - Wait for request & response expectations")
        await fulfillment(of: [requestExpectation, responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testSessionRequestOnAuthenticatedSessionForAChainNotIncludedInCacao() ✅")
    }

    func testFalbackForm_2_5_DappToSessionProposeOnWallet() async throws {
        print("🧪TEST: Starting testFalbackForm_2_5_DappToSessionProposeOnWallet()")

        let fallbackExpectation = expectation(description: "fallback to wc_sessionPropose")
        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)

        print("🧪TEST: Step 1 - Wallet listens for sessionProposalPublisher & approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                do { _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces) } catch { XCTFail("\(error)") }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for sessionSettlePublisher to fulfill fallbackExpectation")
        dapp.sessionSettlePublisher.sink { settledSession in
            Task(priority: .high) {
                fallbackExpectation.fulfill()
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp calls authenticate(...) then modifies URI to remove &methods=wc_sessionAuthenticate")
        let uri = try await dapp.authenticate(AuthRequestParams.stub())!
        let uriStringWithoutMethods = uri.absoluteString.replacingOccurrences(of: "&methods=wc_sessionAuthenticate", with: "")
        let uriWithoutMethods = try WalletConnectURI(uriString: uriStringWithoutMethods)

        print("🧪TEST: Step 4 - Wallet pairs with the modified URI, expecting fallback to wc_sessionPropose")
        try await walletPairingClient.pair(uri: uriWithoutMethods)

        print("🧪TEST: Step 5 - Wait for fallbackExpectation")
        await fulfillment(of: [fallbackExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testFalbackForm_2_5_DappToSessionProposeOnWallet() ✅")
    }

    func testFallbackToSessionProposeIfWalletIsNotSubscribingSessionAuthenticate()  async throws {
        print("🧪TEST: Starting testFallbackToSessionProposeIfWalletIsNotSubscribingSessionAuthenticate()")

        let responseExpectation = expectation(description: "successful response delivered")

        print("🧪TEST: Step 1 - Prepare requiredNamespaces & sessionNamespaces")
        let requiredNamespaces = ProposalNamespace.stubRequired()
        let sessionNamespaces = SessionNamespace.make(toRespond: requiredNamespaces)

        print("🧪TEST: Step 2 - Wallet listens for sessionProposalPublisher & approves")
        wallet.sessionProposalPublisher.sink { [unowned self] (proposal, _) in
            Task(priority: .high) {
                do { _ = try await wallet.approve(proposalId: proposal.id, namespaces: sessionNamespaces) } catch { XCTFail("\(error)") }
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for sessionSettlePublisher to fulfill expectation")
        dapp.sessionSettlePublisher.sink { settledSession in
            Task(priority: .high) {
                responseExpectation.fulfill()
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp calls authenticate(...), wallet pairs, expecting fallback to wc_sessionPropose")
        let uri = try await dapp.authenticate(AuthRequestParams.stub())!
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Step 5 - Wait for responseExpectation to fulfill if fallback succeeded")
        await fulfillment(of: [responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testFallbackToSessionProposeIfWalletIsNotSubscribingSessionAuthenticate() ✅")
    }

    // Link Mode

    func testLinkAuthRequest() async throws {
        print("🧪TEST: Starting testLinkAuthRequest()")

        try await setUpDappForLinkMode()
        dappRelayClient.blockPublishing = true
        walletRelayClient.blockPublishing = true

        let responseExpectation = expectation(description: "successful response delivered")

        print("🧪TEST: Step 1 - Set up a wallet universal link in Dapp storage to prove link mode")
        let walletUniversalLink = "https://test"
        let dappLinkModeLinksStore = CodableStore<Bool>(defaults: dappKeyValueStorage, identifier: SignStorageIdentifiers.linkModeLinks.rawValue)
        dappLinkModeLinksStore.set(true, forKey: walletUniversalLink)

        print("🧪TEST: Step 2 - Wallet listens for authenticateRequestPublisher, approves in link mode")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            Task(priority: .high) {
                let signerFactory = DefaultSignerFactory()
                let signer = MessageSignerFactory(signerFactory: signerFactory).create()
                let supportedAuthPayload = try! wallet.buildAuthPayload(
                    payload: request.payload,
                    supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                    supportedMethods: ["eth_signTransaction", "personal_sign"]
                )
                let siweMessage = try! wallet.formatAuthMessage(payload: supportedAuthPayload, account: walletAccount)
                let signature = try signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                let auth = try wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: walletAccount)
                let (_, approveEnvelope) = try! await wallet.approveSessionAuthenticateLinkMode(requestId: request.id, auths: [auth])
                try dapp.dispatchEnvelope(approveEnvelope)
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for authResponsePublisher success")
        dapp.authResponsePublisher.sink { (_, result) in
            guard case .success = result else { XCTFail(); return }
            responseExpectation.fulfill()
        }
        .store(in: &publishers)

        print("🧪TEST: Step 4 - Dapp calls authenticateLinkMode(...) => requestEnvelope => dispatch on wallet")
        let requestEnvelope = try await dapp.authenticateLinkMode(AuthRequestParams.stub(), walletUniversalLink: walletUniversalLink)
        try wallet.dispatchEnvelope(requestEnvelope)

        print("🧪TEST: Step 5 - Wait for response expectation")
        await fulfillment(of: [responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testLinkAuthRequest() ✅")
    }

    func testLinkSessionRequest() async throws {
        print("🧪TEST: Starting testLinkSessionRequest()")

        try await setUpDappForLinkMode()
        dappRelayClient.blockPublishing = true
        walletRelayClient.blockPublishing = true

        let requestExpectation = expectation(description: "Wallet expects to receive a request")
        let responseExpectation = expectation(description: "Dapp expects to receive a response")

        let requestMethod = "personal_sign"
        let requestParams = [EthSendTransaction.stub()]
        let responseParams = "0xdeadbeef"

        let semaphore = DispatchSemaphore(value: 0)

        print("🧪TEST: Step 1 - Prove link mode for walletUniversalLink in Dapp storage")
        let walletUniversalLink = "https://test"
        let dappLinkModeLinksStore = CodableStore<Bool>(defaults: dappKeyValueStorage, identifier: SignStorageIdentifiers.linkModeLinks.rawValue)
        dappLinkModeLinksStore.set(true, forKey: walletUniversalLink)

        print("🧪TEST: Step 2 - Wallet listens for authenticateRequestPublisher, approves link mode, signals semaphore")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            Task(priority: .high) {
                let signerFactory = DefaultSignerFactory()
                let signer = MessageSignerFactory(signerFactory: signerFactory).create()
                let supportedAuthPayload = try! wallet.buildAuthPayload(
                    payload: request.payload,
                    supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                    supportedMethods: ["eth_signTransaction", "personal_sign"]
                )
                let siweMessage = try! wallet.formatAuthMessage(payload: supportedAuthPayload, account: walletAccount)
                let signature = try signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                let auth = try wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: walletAccount)
                let (_, approveEnvelope) = try! await wallet.approveSessionAuthenticateLinkMode(requestId: request.id, auths: [auth])
                try dapp.dispatchEnvelope(approveEnvelope)
                semaphore.signal()
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp listens for authResponsePublisher, then sends link-mode request => signals semaphore")
        dapp.authResponsePublisher.sink { [unowned self] (_, result) in
            semaphore.wait()
            guard case .success(let (session, _)) = result, let session = session else { XCTFail(); return }
            Task(priority: .high) {
                let request = try! Request(id: RPCID(0), topic: session.topic, method: requestMethod, params: requestParams, chainId: Blockchain("eip155:1")!)
                let requestEnvelope = try! await dapp.requestLinkMode(params: request)!
                try! wallet.dispatchEnvelope(requestEnvelope)
                semaphore.signal()
            }
        }
        .store(in: &publishers)

        print("🧪TEST: Step 4 - Wallet listens for sessionRequestPublisher, responds link mode => signals semaphore")
        wallet.sessionRequestPublisher.sink { [unowned self] (sessionRequest, _) in
            semaphore.wait()
            let receivedParams = try! sessionRequest.params.get([EthSendTransaction].self)
            XCTAssertEqual(receivedParams, requestParams)
            XCTAssertEqual(sessionRequest.method, requestMethod)
            requestExpectation.fulfill()
            Task(priority: .high) {
                let envelope = try! await wallet.respondLinkMode(topic: sessionRequest.topic, requestId: sessionRequest.id, response: .response(AnyCodable(responseParams)))!
                try! dapp.dispatchEnvelope(envelope)
            }
            semaphore.signal()
        }.store(in: &publishers)

        print("🧪TEST: Step 5 - Dapp listens for sessionResponsePublisher, expects success => fulfill responseExpectation")
        dapp.sessionResponsePublisher.sink { response in
            semaphore.wait()
            switch response.result {
            case .response(let resp):
                XCTAssertEqual(try! resp.get(String.self), responseParams)
            case .error:
                XCTFail()
            }
            responseExpectation.fulfill()
        }.store(in: &publishers)

        print("🧪TEST: Step 6 - Dapp calls authenticateLinkMode, wallet dispatches envelope")
        let requestEnvelope = try await dapp.authenticateLinkMode(AuthRequestParams.stub(), walletUniversalLink: walletUniversalLink)
        try wallet.dispatchEnvelope(requestEnvelope)

        print("🧪TEST: Step 7 - Wait for request & response expectations")
        await fulfillment(of: [requestExpectation, responseExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testLinkSessionRequest() ✅")
    }

    func testLinkModeFailsWhenDappDoesNotHaveProofThatWalletSupportsLinkMode() async throws {
        print("🧪TEST: Starting testLinkModeFailsWhenDappDoesNotHaveProofThatWalletSupportsLinkMode()")

        print("🧪TEST: Step 1 - Attempt link mode authentication with no link support proven")
        do {
            try await self.dapp.authenticateLinkMode(AuthRequestParams.stub(), walletUniversalLink: self.walletLinkModeUniversalLink)
            XCTFail("🧪TEST: Expected error but got success.")
        } catch {
            if let authError = error as? LinkAuthRequester.Errors, authError == .walletLinkSupportNotProven {
                print("🧪TEST: Link mode error as expected: .walletLinkSupportNotProven")
            } else {
                XCTFail("🧪TEST: Unexpected error: \(error)")
            }
        }

        print("🧪TEST: Finished testLinkModeFailsWhenDappDoesNotHaveProofThatWalletSupportsLinkMode() ✅")
    }

    func testUpgradeFromRelayToLinkMode() async throws {
        print("🧪TEST: Starting testUpgradeFromRelayToLinkMode()")

        let linkModeUpgradeExpectation = expectation(description: "successful upgraded to link mode")
        try await setUpDappForLinkMode()

        print("🧪TEST: Step 1 - Wallet listens for authenticateRequestPublisher with eip191, then blocks publishing")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            Task(priority: .high) {
                let signerFactory = DefaultSignerFactory()
                let signer = MessageSignerFactory(signerFactory: signerFactory).create()
                let supportedAuthPayload = try! wallet.buildAuthPayload(
                    payload: request.payload,
                    supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                    supportedMethods: ["eth_signTransaction", "personal_sign"]
                )
                let siweMessage = try! wallet.formatAuthMessage(payload: supportedAuthPayload, account: walletAccount)
                let signature = try! signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                let auth = try! wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: walletAccount)
                _ = try! await wallet.approveSessionAuthenticate(requestId: request.id, auths: [auth])
                walletRelayClient.blockPublishing = true
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 2 - Dapp listens for authResponsePublisher, blocks publishing, attempts link upgrade")
        dapp.authResponsePublisher.sink { [unowned self] (_, result) in
            dappRelayClient.blockPublishing = true
            guard case .success = result else { XCTFail(); return }
            Task {
                try! await self.dapp.authenticateLinkMode(AuthRequestParams.stub(), walletUniversalLink: self.walletLinkModeUniversalLink)
                linkModeUpgradeExpectation.fulfill()
            }
        }.store(in: &publishers)

        print("🧪TEST: Step 3 - Dapp calls authenticate(...), wallet pairs, waiting for link mode upgrade")
        let uri = try await dapp.authenticate(AuthRequestParams.stub(), walletUniversalLink: walletLinkModeUniversalLink)!
        try await walletPairingClient.pair(uri: uri)
        await fulfillment(of: [linkModeUpgradeExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testUpgradeFromRelayToLinkMode() ✅")
    }

    func testUpgradeSessionToLinkModeAndSendRequestOverLinkMode() async throws {
        print("🧪TEST: Starting testUpgradeSessionToLinkModeAndSendRequestOverLinkMode...")

        print("🧪TEST: Step 1 - Calling setUpDappForLinkMode()")
        try await setUpDappForLinkMode()
        print("🧪TEST: Finished setUpDappForLinkMode()")

        let requestMethod = "personal_sign"
        let requestParams = [EthSendTransaction.stub()]
        let responseParams = "0xdeadbeef"
        let sessionResponseOnLinkModeExpectation = expectation(description: "Dapp expects to receive a response")

        let semaphore = DispatchSemaphore(value: 0)

        print("🧪TEST: Subscribing to wallet.authenticateRequestPublisher...")
        wallet.authenticateRequestPublisher.sink { [unowned self] (request, _) in
            print("🧪TEST: Received authenticate request from wallet.authenticateRequestPublisher. Processing...")
            Task(priority: .high) {
                do {
                    let signerFactory = DefaultSignerFactory()
                    let signer = MessageSignerFactory(signerFactory: signerFactory).create()
                    let supportedAuthPayload = try wallet.buildAuthPayload(
                        payload: request.payload,
                        supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!],
                        supportedMethods: ["eth_signTransaction", "personal_sign"]
                    )
                    let siweMessage = try wallet.formatAuthMessage(payload: supportedAuthPayload, account: walletAccount)
                    let signature = try signer.sign(message: siweMessage, privateKey: prvKey, type: .eip191)
                    let auth = try wallet.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: walletAccount)

                    print("🧪TEST: Approving session authenticate on wallet...")
                    _ = try await wallet.approveSessionAuthenticate(requestId: request.id, auths: [auth])
                    print("🧪TEST: Wallet approved session authenticate. Signaling semaphore.")
                    semaphore.signal()
                } catch {
                    XCTFail("Failed to approve session authenticate: \(error)")
                    semaphore.signal()
                }
            }
        }
        .store(in: &publishers)

        print("🧪TEST: Subscribing to dapp.authResponsePublisher...")
        dapp.authResponsePublisher.sink { [unowned self] (_, result) in
            print("🧪TEST: Dapp received auth response. Waiting on semaphore...")
            semaphore.wait()

            print("🧪TEST: Blocking relay publishing to use link mode exclusively...")
            dappRelayClient.blockPublishing = true
            walletRelayClient.blockPublishing = true

            guard case .success(let (session, _)) = result, let session = session else {
                XCTFail("Auth response did not return a valid session.")
                return
            }
            print("🧪TEST: Auth responded with a valid session. Topic: \(session.topic)")

            Task(priority: .high) {
                do {
                    print("🧪TEST: Sending link-mode request from dapp to wallet...")
                    let request = try Request(
                        id: RPCID(0),
                        topic: session.topic,
                        method: requestMethod,
                        params: requestParams,
                        chainId: Blockchain("eip155:1")!
                    )
                    let requestEnvelope = try await self.dapp.requestLinkMode(params: request)!
                    try self.wallet.dispatchEnvelope(requestEnvelope)
                    print("🧪TEST: Dispatched the request envelope to the wallet over link mode.")
                } catch {
                    XCTFail("Failed to dispatch link-mode request: \(error)")
                }
            }
        }
        .store(in: &publishers)

        print("🧪TEST: Subscribing to wallet.sessionRequestPublisher...")
        wallet.sessionRequestPublisher.sink { [unowned self] (sessionRequest, _) in
            print("🧪TEST: Wallet received a session request. Preparing link-mode response...")
            Task(priority: .high) {
                do {
                    let envelope = try await wallet.respondLinkMode(
                        topic: sessionRequest.topic,
                        requestId: sessionRequest.id,
                        response: .response(AnyCodable(responseParams))
                    )!
                    try dapp.dispatchEnvelope(envelope)
                    print("🧪TEST: Responded to request and dispatched the response envelope back to Dapp.")
                } catch {
                    XCTFail("Failed to respond or dispatch envelope: \(error)")
                }
            }
        }
        .store(in: &publishers)

        print("🧪TEST: Subscribing to dapp.sessionResponsePublisher...")
        dapp.sessionResponsePublisher.sink { response in
            print("🧪TEST: Dapp received session response. Fulfilling expectation...")
            sessionResponseOnLinkModeExpectation.fulfill()
        }
        .store(in: &publishers)

        print("🧪TEST: Starting normal authenticate over universal link: \(walletLinkModeUniversalLink)")
        let uri = try await dapp.authenticate(AuthRequestParams.stub(), walletUniversalLink: walletLinkModeUniversalLink)!
        print("🧪TEST: Pairing on wallet with URI: \(uri)")
        try await walletPairingClient.pair(uri: uri)

        print("🧪TEST: Waiting for sessionResponseOnLinkModeExpectation (timeout = \(InputConfig.defaultTimeout) seconds)...")
        await fulfillment(of: [sessionResponseOnLinkModeExpectation], timeout: InputConfig.defaultTimeout)

        print("🧪TEST: Finished testUpgradeSessionToLinkModeAndSendRequestOverLinkMode ✅")
    }
}
