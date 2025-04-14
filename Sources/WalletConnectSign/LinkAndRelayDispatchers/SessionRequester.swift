import Foundation


final class SessionRequester {
    private let sessionStore: WCSessionStorage
    private let networkingInteractor: NetworkInteracting
    private let logger: ConsoleLogging
    private let tvfCollector: TVFCollectorProtocol
    private let walletServiceRequester: WalletServiceSessionRequestable
    private let walletServiceFinder: WalletServiceFinder

    init(
        sessionStore: WCSessionStorage,
        networkingInteractor: NetworkInteracting,
        logger: ConsoleLogging,
        tvfCollector: TVFCollectorProtocol,
        walletServiceRequester: WalletServiceSessionRequestable? = nil,
        walletServiceFinder: WalletServiceFinder? = nil
    ) {
        self.sessionStore = sessionStore
        self.networkingInteractor = networkingInteractor
        self.logger = logger
        self.tvfCollector = tvfCollector
        self.walletServiceRequester = walletServiceRequester ?? WalletServiceSessionRequester(logger: logger)
        self.walletServiceFinder = walletServiceFinder ?? WalletServiceFinder(logger: logger)
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
        
        // Check if this request should be redirected to a wallet service
        if let walletServiceURL = walletServiceFinder.findMatchingWalletService(for: request, in: session) {
            logger.debug("Redirecting request to wallet service: \(walletServiceURL)")
            do {
                let _ = try await walletServiceRequester.request(request, to: walletServiceURL)
                logger.debug("Wallet service request completed successfully")
                return
            } catch {
                logger.error("Wallet service request failed: \(error)")
                throw error
            }
        }
        
        // Default flow - send through relay
        let chainRequest = SessionType.RequestParams.Request(method: request.method, params: request.params, expiryTimestamp: request.expiryTimestamp)
        let sessionRequestParams = SessionType.RequestParams(request: chainRequest, chainId: request.chainId)
        let ttl = try request.calculateTtl()
        let protocolMethod = SessionRequestProtocolMethod(ttl: ttl)

        let rpcRequest = RPCRequest(method: protocolMethod.method, params: sessionRequestParams, rpcid: request.id)

        let tvfData = tvfCollector.collect(rpcMethod: request.method, rpcParams: request.params, chainID: request.chainId, rpcResult: nil, tag: protocolMethod.requestConfig.tag)

        try await networkingInteractor.request(rpcRequest, topic: request.topic, protocolMethod: SessionRequestProtocolMethod(), tvfData: tvfData)
    }
}
