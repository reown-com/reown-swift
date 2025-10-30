import Foundation
import Combine

final class ApproveEngine {
    enum Errors: Error {
        case proposalNotFound
        case relayNotFound
        case pairingNotFound
        case sessionNotFound
        case agreementMissingOrInvalid
        case networkNotConnected
        case proposalExpired
        case emtySessionNamespacesForbidden
    }

    var onSessionProposal: ((Session.Proposal, VerifyContext?) -> Void)?
    var onSessionRejected: ((Session.Proposal, Reason) -> Void)?
    var onSessionSettle: ((Session, ProposalRequestsResponses?) -> Void)?

    private let networkingInteractor: NetworkInteracting
    private let pairingStore: WCPairingStorage
    private let sessionStore: WCSessionStorage
    private let verifyClient: VerifyClientProtocol
    private let proposalPayloadsStore: CodableStore<RequestSubscriptionPayload<SessionType.ProposeParams>>
    private let verifyContextStore: CodableStore<VerifyContext>
    private let sessionTopicToProposal: CodableStore<Session.Proposal>
    private let pairingRegisterer: PairingRegisterer
    private let metadata: AppMetadata
    private let kms: KeyManagementServiceProtocol
    private let logger: ConsoleLogging
    private let rpcHistory: RPCHistory
    private let authRequestSubscribersTracking: AuthRequestSubscribersTracking
    private let eventsClient: EventsClientProtocol
    private let approveEngineLoggingHelper: ApproveEngineLoggingHelper

    private var publishers = Set<AnyCancellable>()

    init(
        networkingInteractor: NetworkInteracting,
        proposalPayloadsStore: CodableStore<RequestSubscriptionPayload<SessionType.ProposeParams>>,
        verifyContextStore: CodableStore<VerifyContext>,
        sessionTopicToProposal: CodableStore<Session.Proposal>,
        pairingRegisterer: PairingRegisterer,
        metadata: AppMetadata,
        kms: KeyManagementServiceProtocol,
        logger: ConsoleLogging,
        pairingStore: WCPairingStorage,
        sessionStore: WCSessionStorage,
        verifyClient: VerifyClientProtocol,
        rpcHistory: RPCHistory,
        authRequestSubscribersTracking: AuthRequestSubscribersTracking,
        eventsClient: EventsClientProtocol
    ) {
        self.networkingInteractor = networkingInteractor
        self.proposalPayloadsStore = proposalPayloadsStore
        self.verifyContextStore = verifyContextStore
        self.sessionTopicToProposal = sessionTopicToProposal
        self.pairingRegisterer = pairingRegisterer
        self.metadata = metadata
        self.kms = kms
        self.logger = logger
        self.pairingStore = pairingStore
        self.sessionStore = sessionStore
        self.verifyClient = verifyClient
        self.rpcHistory = rpcHistory
        self.authRequestSubscribersTracking = authRequestSubscribersTracking
        self.eventsClient = eventsClient
        self.approveEngineLoggingHelper = ApproveEngineLoggingHelper(logger: logger)

        setupRequestSubscriptions()
        setupResponseSubscriptions()
        setupResponseErrorSubscriptions()
    }


    func approveProposal(proposerPubKey: String, validating sessionNamespaces: [String: SessionNamespace], sessionProperties: [String: String]? = nil, scopedProperties: [String: String]? = nil, proposalRequestsResponses: ProposalRequestsResponses? = nil) async throws -> Session {
        eventsClient.startTrace(topic: "")
        logger.debug("Approving session proposal...")

        approveEngineLoggingHelper.logSessionNamespaces(sessionNamespaces)

        eventsClient.saveTraceEvent(SessionApproveExecutionTraceEvents.approvingSessionProposal)

        guard !sessionNamespaces.isEmpty else {
            eventsClient.saveTraceEvent(ApproveSessionTraceErrorEvents.sessionNamespacesValidationFailure)
            throw Errors.emtySessionNamespacesForbidden
        }

        guard let payload = try proposalPayloadsStore.get(key: proposerPubKey) else {
            eventsClient.saveTraceEvent(ApproveSessionTraceErrorEvents.proposalNotFound)
            throw Errors.proposalNotFound
        }
        let pairingTopic = payload.topic

        eventsClient.setTopic(pairingTopic)

        let proposal = payload.request

        guard !proposal.isExpired() else {
            logger.debug("Proposal has expired, topic: \(payload.topic)")
            eventsClient.saveTraceEvent(ApproveSessionTraceErrorEvents.proposalExpired)
            proposalPayloadsStore.delete(forKey: proposerPubKey)
            throw Errors.proposalExpired
        }

        let networkConnectionStatus = await resolveNetworkConnectionStatus()
        guard networkConnectionStatus == .connected else {
            eventsClient.saveTraceEvent(ApproveSessionTraceErrorEvents.networkNotConnected)
            throw Errors.networkNotConnected
        }

        do {
            eventsClient.saveTraceEvent(SessionApproveExecutionTraceEvents.sessionNamespacesValidationStarted)
            try Namespace.validate(sessionNamespaces)
            try Namespace.validateApproved(sessionNamespaces, against: proposal.requiredNamespaces)
            eventsClient.saveTraceEvent(SessionApproveExecutionTraceEvents.sessionNamespacesValidationSuccess)
        } catch {
            eventsClient.saveTraceEvent(ApproveSessionTraceErrorEvents.sessionNamespacesValidationFailure)
            throw error
        }

        let selfPublicKey = try kms.createX25519KeyPair()

        guard let agreementKey = try? kms.performKeyAgreement(
            selfPublicKey: selfPublicKey,
            peerPublicKey: proposal.proposer.publicKey
        ) else {
            eventsClient.saveTraceEvent(ApproveSessionTraceErrorEvents.agreementMissingOrInvalid)
            throw Errors.agreementMissingOrInvalid
        }

        let sessionTopic = agreementKey.derivedTopic()
        try kms.setAgreementSecret(agreementKey, topic: sessionTopic)

        guard let relay = proposal.relays.first else {
            eventsClient.saveTraceEvent(ApproveSessionTraceErrorEvents.relayNotFound)
            throw Errors.relayNotFound
        }

        let result = SessionType.ProposeResponse(relay: relay, responderPublicKey: selfPublicKey.hexRepresentation)
        let response = RPCResponse(id: payload.id, result: result)
        
        let settleParams = try createSettleParams(sessionTopic: sessionTopic, proposal: proposal, namespaces: sessionNamespaces, sessionProperties: sessionProperties, scopedProperties: scopedProperties, proposalRequestsResponses: proposalRequestsResponses)
        
        let settleRequest = RPCRequest(method: SessionSettleProtocolMethod().method, params: settleParams)
        
        let approvedChains = ApprovedSessionMetadataBuilder.chains(from: settleParams.namespaces)
        let approvedMethods = ApprovedSessionMetadataBuilder.methods(from: settleParams.namespaces)
        let approvedEvents = ApprovedSessionMetadataBuilder.events(from: settleParams.namespaces)
        
        do {
            try await networkingInteractor.approveSession(
                pairingTopic: pairingTopic,
                sessionTopic: sessionTopic,
                sessionProposalResponse: response,
                sessionSettleRequest: settleRequest,
                approvedChains: approvedChains,
                approvedMethods: approvedMethods,
                approvedEvents: approvedEvents
            )
        } catch {
            eventsClient.saveTraceEvent(ApproveSessionTraceErrorEvents.approveSessionFailure)
            throw error
        }
        
        let session = createSession(topic: sessionTopic, proposal: proposal, pairingTopic: pairingTopic, settleParams: settleParams)
        
        sessionStore.setSession(session)

        onSessionSettle?(session.publicRepresentation(), nil)
        eventsClient.saveTraceEvent(SessionApproveExecutionTraceEvents.approvSessionSuccess)
        logger.debug("wc_sessionApprove have been sent")
        
        proposalPayloadsStore.delete(forKey: proposerPubKey)
        verifyContextStore.delete(forKey: proposerPubKey)
        return session.publicRepresentation()
        
    }

    func reject(proposerPubKey: String, reason: SignReasonCode) async throws {
        guard let payload = try proposalPayloadsStore.get(key: proposerPubKey) else {
            throw Errors.proposalNotFound
        }
 
        try await networkingInteractor.respondError(
            topic: payload.topic,
            requestId: payload.id,
            protocolMethod: SessionProposeProtocolMethod.responseReject(),
            reason: reason
        )

        if let pairingTopic = rpcHistory.get(recordId: payload.id)?.topic {
            Task {
                networkingInteractor.unsubscribe(topic: pairingTopic)
            }
        }

        proposalPayloadsStore.delete(forKey: proposerPubKey)
        verifyContextStore.delete(forKey: proposerPubKey)
    }

    private func removePairing(pairingTopic: String) {
        pairingStore.delete(topic: pairingTopic)
        networkingInteractor.unsubscribe(topic: pairingTopic)
        kms.deleteSymmetricKey(for: pairingTopic)
    }
    
    func createSettleParams(sessionTopic: String, proposal: SessionProposal, namespaces: [String: SessionNamespace], sessionProperties: [String: String]?, scopedProperties: [String: String]?, proposalRequestsResponses: ProposalRequestsResponses?) throws -> SessionType.SettleParams {
        
        guard let agreementKeys = kms.getAgreementSecret(for: sessionTopic) else {
            throw Errors.agreementMissingOrInvalid
        }
        let selfParticipant = Participant(
            publicKey: agreementKeys.publicKey.hexRepresentation,
            metadata: metadata
        )
        guard let relay = proposal.relays.first else {
            throw Errors.relayNotFound
        }

        let expiry = Date()
            .addingTimeInterval(TimeInterval(WCSession.defaultTimeToLive))
            .timeIntervalSince1970

        let settleParams = SessionType.SettleParams(
            relay: relay,
            controller: selfParticipant,
            namespaces: namespaces,
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties,
            expiry: Int64(expiry),
            proposalRequestsResponses: proposalRequestsResponses
        )
        
        return settleParams
    }
    
    func createSession(topic: String, proposal: SessionProposal, pairingTopic: String, settleParams: SessionType.SettleParams) -> WCSession {

        let verifyContext = (try? verifyContextStore.get(key: proposal.proposer.publicKey)) ?? verifyClient.createVerifyContext(origin: nil, domain: proposal.proposer.metadata.url, isScam: false, isVerified: nil)

        let session = WCSession(
            topic: topic,
            pairingTopic: pairingTopic,
            timestamp: Date(),
            selfParticipant: settleParams.controller,
            peerParticipant: proposal.proposer,
            settleParams: settleParams,
            requiredNamespaces: proposal.requiredNamespaces,
            acknowledged: false,
            transportType: .relay,
            verifyContext: verifyContext
        )

        logger.debug("Sending session settle request")


        let protocolMethod = SessionSettleProtocolMethod()
        let request = RPCRequest(method: protocolMethod.method, params: settleParams)

        return session
    }
}

// MARK: - Privates

private extension ApproveEngine {

    func setupRequestSubscriptions() {
        pairingRegisterer.register(method: SessionProposeProtocolMethod.responseAutoReject())
            .sink { [weak self] (payload: RequestSubscriptionPayload<SessionType.ProposeParams>) in
                guard let self = self else { return }
                guard let pairing = pairingStore.getPairing(forTopic: payload.topic) else { return }
                let responseApproveMethod = SessionAuthenticatedProtocolMethod.responseApprove().method
                if let methods = pairing.methods,
                   methods.contains(responseApproveMethod),
                    authRequestSubscribersTracking.hasSubscribers()
                {
                    logger.debug("Ignoring Session Proposal")
                    // respond with an error?
                    return
                }
                handleSessionProposeRequest(payload: payload)
            }.store(in: &publishers)

        networkingInteractor.requestSubscription(on: SessionSettleProtocolMethod())
            .sink { [unowned self] (payload: RequestSubscriptionPayload<SessionType.SettleParams>) in
                handleSessionSettleRequest(payload: payload)
            }.store(in: &publishers)
    }

    func setupResponseSubscriptions() {
        networkingInteractor.responseSubscription(on: SessionProposeProtocolMethod.responseApprove())
            .sink { [unowned self] (payload: ResponseSubscriptionPayload<SessionType.ProposeParams, SessionType.ProposeResponse>) in
                handleSessionProposeResponse(payload: payload)
            }.store(in: &publishers)

        networkingInteractor.responseSubscription(on: SessionSettleProtocolMethod())
            .sink { [unowned self] (payload: ResponseSubscriptionPayload<SessionType.SettleParams, Bool>) in
                handleSessionSettleResponse(payload: payload)
            }.store(in: &publishers)
    }

    func setupResponseErrorSubscriptions() {
        networkingInteractor.responseErrorSubscription(on: SessionProposeProtocolMethod.responseApprove())
            .sink { [unowned self] (payload: ResponseSubscriptionErrorPayload<SessionType.ProposeParams>) in
                handleSessionProposeResponseError(payload: payload)
            }.store(in: &publishers)

        networkingInteractor.responseErrorSubscription(on: SessionSettleProtocolMethod())
            .sink { [unowned self] (payload: ResponseSubscriptionErrorPayload<SessionType.SettleParams>) in
                handleSessionSettleResponseError(payload: payload)
            }.store(in: &publishers)
    }

    func respondError(payload: SubscriptionPayload, reason: SignReasonCode, protocolMethod: ProtocolMethod) {
        Task(priority: .high) {
            do {
                try await networkingInteractor.respondError(topic: payload.topic, requestId: payload.id, protocolMethod: protocolMethod, reason: reason)
            } catch {
                logger.error("Respond Error failed with: \(error.localizedDescription)")
            }
        }
    }

    // MARK: SessionProposeResponse
    // TODO: Move to Non-Controller SettleEngine
    func handleSessionProposeResponse(payload: ResponseSubscriptionPayload<SessionType.ProposeParams, SessionType.ProposeResponse>) {
        do {
            let selfPublicKey = try AgreementPublicKey(hex: payload.request.proposer.publicKey)
            let agreementKeys = try kms.performKeyAgreement(selfPublicKey: selfPublicKey, peerPublicKey: payload.response.responderPublicKey)

            let sessionTopic = agreementKeys.derivedTopic()
            logger.debug("Received Session Proposal response")

            try kms.setAgreementSecret(agreementKeys, topic: sessionTopic)

            let proposal = payload.request.publicRepresentation(pairingTopic: payload.topic)
            sessionTopicToProposal.set(proposal, forKey: sessionTopic)
            Task(priority: .high) {
                try await networkingInteractor.subscribe(topic: sessionTopic)
                removePairing(pairingTopic: payload.topic)
            }
        } catch {
            return logger.debug(error.localizedDescription)
        }
    }

    func handleSessionProposeResponseError(payload: ResponseSubscriptionErrorPayload<SessionType.ProposeParams>) {
        removePairing(pairingTopic: payload.topic)
        logger.debug("Session Proposal has been rejected")
        kms.deletePrivateKey(for: payload.request.proposer.publicKey)

        onSessionRejected?(
            payload.request.publicRepresentation(pairingTopic: payload.topic),
            SessionType.Reason(code: payload.error.code, message: payload.error.message)
        )
    }

    // MARK: SessionSettleResponse

    func handleSessionSettleResponse(payload: ResponseSubscriptionPayload<SessionType.SettleParams, Bool>) {
        guard var session = sessionStore.getSession(forTopic: payload.topic) else {
            return logger.debug(Errors.sessionNotFound.localizedDescription)
        }

        logger.debug("Received session settle response")
        session.acknowledge()
        sessionStore.setSession(session)
    }

    func handleSessionSettleResponseError(payload: ResponseSubscriptionErrorPayload<SessionType.SettleParams>) {
        guard let session = sessionStore.getSession(forTopic: payload.topic) else {
            return logger.debug(Errors.sessionNotFound.localizedDescription)
        }

        logger.error("Error - session rejected, Reason: \(payload.error)")
        networkingInteractor.unsubscribe(topic: payload.topic)
        sessionStore.delete(topic: payload.topic)
        kms.deleteAgreementSecret(for: payload.topic)
        kms.deletePrivateKey(for: session.publicKey!)
    }

    // MARK: SessionProposeRequest

    func handleSessionProposeRequest(payload: RequestSubscriptionPayload<SessionType.ProposeParams>) {
        logger.debug("Received Session Proposal")
        let proposal = payload.request

        approveEngineLoggingHelper.logProposalNamespaces(title: "Required Namespaces", proposal.requiredNamespaces)
        if let optionalNamespaces = proposal.optionalNamespaces {
            approveEngineLoggingHelper.logProposalNamespaces(title: "Optional Namespaces", optionalNamespaces)
        }

        do { try Namespace.validate(proposal.requiredNamespaces) } catch {
            return respondError(payload: payload, reason: .invalidUpdateRequest, protocolMethod: SessionProposeProtocolMethod.responseAutoReject())
        }
        proposalPayloadsStore.set(payload, forKey: proposal.proposer.publicKey)
        
        pairingRegisterer.setReceived(pairingTopic: payload.topic)

        if let verifyContext = try? verifyContextStore.get(key: proposal.proposer.publicKey) {
            onSessionProposal?(proposal.publicRepresentation(pairingTopic: payload.topic), verifyContext)
            return
        }
        
        Task(priority: .high) { [weak self] in
            guard let self = self else {return}
            do {
                let response: VerifyResponse
                if let attestation = payload.attestation,
                   let messageId = payload.encryptedMessage.data(using: .utf8)?.sha256().toHexString() {
                    response = try await verifyClient.verify(.v2(attestationJWT: attestation, messageId: messageId))
                } else {
                    let assertionId = payload.decryptedPayload.sha256().toHexString()
                    response = try await verifyClient.verify(.v1(assertionId: assertionId))
                }
                let verifyContext = verifyClient.createVerifyContext(
                    origin: response.origin,
                    domain: payload.request.proposer.metadata.url,
                    isScam: response.isScam,
                    isVerified: response.isVerified
                )
                verifyContextStore.set(verifyContext, forKey: proposal.proposer.publicKey)
                onSessionProposal?(proposal.publicRepresentation(pairingTopic: payload.topic), verifyContext)
            } catch {
                let verifyContext = verifyClient.createVerifyContext(origin: nil, domain: payload.request.proposer.metadata.url, isScam: nil, isVerified: nil)
                onSessionProposal?(proposal.publicRepresentation(pairingTopic: payload.topic), verifyContext)
                return
            }
        }
    }

    // MARK: SessionSettleRequest

    func handleSessionSettleRequest(payload: RequestSubscriptionPayload<SessionType.SettleParams>) {
        logger.debug("Did receive session settle request")

        let protocolMethod = SessionSettleProtocolMethod()

        let sessionTopic = payload.topic

        guard let proposal = try? sessionTopicToProposal.get(key: sessionTopic) else {
            return respondError(payload: payload, reason: .sessionSettlementFailed, protocolMethod: protocolMethod)
        }
        let pairingTopic = proposal.pairingTopic
        let proposedNamespaces = proposal.requiredNamespaces

        let params = payload.request
        let sessionNamespaces = params.namespaces

        do {
            try Namespace.validate(sessionNamespaces)
            try Namespace.validateApproved(sessionNamespaces, against: proposedNamespaces)
        } catch WalletConnectError.unsupportedNamespace(let reason) {
            return respondError(payload: payload, reason: reason, protocolMethod: protocolMethod)
        } catch {
            return respondError(payload: payload, reason: .invalidUpdateRequest, protocolMethod: protocolMethod)
        }

        let agreementKeys = kms.getAgreementSecret(for: sessionTopic)!
        let selfParticipant = Participant(
            publicKey: agreementKeys.publicKey.hexRepresentation,
            metadata: metadata
        )

        let session = WCSession(
            topic: sessionTopic,
            pairingTopic: pairingTopic,
            timestamp: Date(),
            selfParticipant: selfParticipant,
            peerParticipant: params.controller,
            settleParams: params,
            requiredNamespaces: proposedNamespaces,
            acknowledged: true,
            transportType: .relay,
            verifyContext: nil
        )
        sessionStore.setSession(session)

        Task(priority: .high) {
            try await networkingInteractor.respondSuccess(topic: payload.topic, requestId: payload.id, protocolMethod: protocolMethod)
        }
        let publicSession = session.publicRepresentation()
        let responses = params.proposalRequestsResponses?.authentication?.isEmpty == false ? params.proposalRequestsResponses : nil
        onSessionSettle?(publicSession, responses)
    }
    
    func resolveNetworkConnectionStatus() async -> NetworkConnectionStatus {
        return await withCheckedContinuation { continuation in
            let cancellable = networkingInteractor.networkConnectionStatusPublisher.sink { value in
                continuation.resume(returning: value)
            }
            
            Task(priority: .high) {
                await withTaskCancellationHandler {
                    cancellable.cancel()
                } onCancel: { }
            }
        }
    }
}

enum ApprovedSessionMetadataBuilder {
    static func chains(from namespaces: [String: SessionNamespace]) -> [String] {
        var chains = Set<String>()
        namespaces.values.forEach { namespace in
            if let namespaceChains = namespace.chains, !namespaceChains.isEmpty {
                namespaceChains.forEach { chain in
                    chains.insert(chain.absoluteString)
                }
            } else {
                namespace.accounts.forEach { account in
                    chains.insert(account.blockchain.absoluteString)
                }
            }
        }

        return chains.sorted()
    }

    static func methods(from namespaces: [String: SessionNamespace]) -> [String] {
        let methods = namespaces.values.reduce(into: Set<String>()) { result, namespace in
            result.formUnion(namespace.methods)
        }
        return methods.sorted()
    }

    static func events(from namespaces: [String: SessionNamespace]) -> [String] {
        let events = namespaces.values.reduce(into: Set<String>()) { result, namespace in
            result.formUnion(namespace.events)
        }
        return events.sorted()
    }
}

// MARK: - LocalizedError
extension ApproveEngine.Errors: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .proposalNotFound:
            return "Proposal not found."
        case .relayNotFound:
            return "Relay not found."
        case .pairingNotFound:
            return "Pairing not found."
        case .sessionNotFound:
            return "Session not found."
        case .agreementMissingOrInvalid:
            return "Agreement missing or invalid."
        case .networkNotConnected:
            return "Network not connected."
        case .proposalExpired:
            return "Proposal expired."
        case .emtySessionNamespacesForbidden:
            return "Session Namespaces Cannot Be Empty"
        }
    }
}
