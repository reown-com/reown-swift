
import Foundation

class SessionResponder {
    enum Errors: Error {
        case sessionRequestExpired
    }
    private let logger: ConsoleLogging
    private let sessionStore: WCSessionStorage
    private let networkingInteractor: NetworkInteracting
    private let verifyContextStore: CodableStore<VerifyContext>
    private let sessionRequestsProvider: SessionRequestsProvider
    private let historyService: HistoryService
    private let tvfCollector: TVFCollector

    init(
        logger: ConsoleLogging,
        sessionStore: WCSessionStorage,
        networkingInteractor: NetworkInteracting,
        verifyContextStore: CodableStore<VerifyContext>,
        sessionRequestsProvider: SessionRequestsProvider,
        historyService: HistoryService,
        tvfCollector: TVFCollector
    ) {
        self.logger = logger
        self.sessionStore = sessionStore
        self.networkingInteractor = networkingInteractor
        self.verifyContextStore = verifyContextStore
        self.sessionRequestsProvider = sessionRequestsProvider
        self.historyService = historyService
        self.tvfCollector = tvfCollector
    }

    func respondSessionRequest(topic: String, requestId: RPCID, response: RPCResult) async throws {
        guard sessionStore.hasSession(forTopic: topic),
        let (request, _) = historyService.getSessionRequest(id: requestId)
        else {
            throw WalletConnectError.noSessionMatchingTopic(topic)
        }

        let protocolMethod = SessionRequestProtocolMethod()

        guard sessionRequestNotExpired(requestId: requestId) else {
            try await networkingInteractor.respondError(
                topic: topic,
                requestId: requestId,
                protocolMethod: protocolMethod,
                reason: SignReasonCode.sessionRequestExpired
            )
            verifyContextStore.delete(forKey: requestId.string)
            throw Errors.sessionRequestExpired
        }



        let tvfData = tvfCollector.collect(rpcMethod: request.method, rpcParams: request.params, chainID: request.chainId, rpcResult: response, tag: protocolMethod.responseConfig.tag)

        try await networkingInteractor.respond(
            topic: topic,
            response: RPCResponse(id: requestId, outcome: response),
            protocolMethod: protocolMethod,
            tvfData: tvfData
        )
        verifyContextStore.delete(forKey: requestId.string)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else {return}
            sessionRequestsProvider.emitRequestIfPending()
        }
    }

    private func sessionRequestNotExpired(requestId: RPCID) -> Bool {
        guard let request = historyService.getSessionRequest(id: requestId)?.request
        else { return false }

        return !request.isExpired()
    }
}
