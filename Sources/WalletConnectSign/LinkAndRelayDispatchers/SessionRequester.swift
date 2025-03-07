
import Foundation

final class SessionRequester {
    private let sessionStore: WCSessionStorage
    private let networkingInteractor: NetworkInteracting
    private let logger: ConsoleLogging
    private let tvfCollector: TVFCollector

    init(
        sessionStore: WCSessionStorage,
        networkingInteractor: NetworkInteracting,
        logger: ConsoleLogging,
        tvfCollector: TVFCollector
    ) {
        self.sessionStore = sessionStore
        self.networkingInteractor = networkingInteractor
        self.logger = logger
        self.tvfCollector = tvfCollector
    }

    func request(_ request: Request) async throws {
        logger.debug("will request on session topic: \(request.topic)")
        guard let session = sessionStore.getSession(forTopic: request.topic), session.acknowledged else {
            logger.debug("Could not find session for topic \(request.topic)")
            return
        }
        guard session.hasPermission(forMethod: request.method, onChain: request.chainId) else {
            logger.debug("Invalid namespaces")
            throw WalletConnectError.invalidPermissions
        }
        let chainRequest = SessionType.RequestParams.Request(method: request.method, params: request.params, expiryTimestamp: request.expiryTimestamp)
        let sessionRequestParams = SessionType.RequestParams(request: chainRequest, chainId: request.chainId)
        let ttl = try request.calculateTtl()
        let protocolMethod = SessionRequestProtocolMethod(ttl: ttl)

        let rpcRequest = RPCRequest(method: protocolMethod.method, params: sessionRequestParams, rpcid: request.id)

        let tvfData = tvfCollector.collect(rpcMethod: request.method, rpcParams: request.params, chainID: request.chainId, rpcResult: nil, tag: protocolMethod.requestConfig.tag)


        try await networkingInteractor.request(rpcRequest, topic: request.topic, protocolMethod: SessionRequestProtocolMethod(), tvfData: tvfData)
    }
}
