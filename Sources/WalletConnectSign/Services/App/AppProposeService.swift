import Foundation

final class AppProposeService {
    private let metadata: AppMetadata
    private let networkingInteractor: NetworkInteracting
    private let kms: KeyManagementServiceProtocol
    private let logger: ConsoleLogging

    init(
        metadata: AppMetadata,
        networkingInteractor: NetworkInteracting,
        kms: KeyManagementServiceProtocol,
        logger: ConsoleLogging
    ) {
        self.metadata = metadata
        self.networkingInteractor = networkingInteractor
        self.kms = kms
        self.logger = logger
    }

    func propose(
        pairingTopic: String,
        namespaces: [String: ProposalNamespace],
        optionalNamespaces: [String: ProposalNamespace]? = nil,
        sessionProperties: [String: String]? = nil,
        scopedProperties: [String: String]? = nil,
        relay: RelayProtocolOptions
    ) async throws {
        logger.debug("Propose Session on topic: \(pairingTopic)")
        
        // Move required namespaces to optional namespaces to avoid connection problems
        let mergedOptionalNamespaces = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: namespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        // Validate the merged optional namespaces
        try Namespace.validate(mergedOptionalNamespaces)
        if let sessionProperties {
            try SessionProperties.validate(sessionProperties)
        }
        
        let protocolMethod = SessionProposeProtocolMethod.responseApprove()
        let publicKey = try! kms.createX25519KeyPair()
        let proposer = Participant(
            publicKey: publicKey.hexRepresentation,
            metadata: metadata)
        
        let proposal = SessionProposal(
            relays: [relay],
            proposer: proposer,
            requiredNamespaces: [:], // Empty required namespaces as per the solution
            optionalNamespaces: mergedOptionalNamespaces,
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties
        )
        
        
        let request = RPCRequest(method: protocolMethod.method, params: proposal)
        try await networkingInteractor.proposeSession(request, topic: pairingTopic)
    }
}


final class LinkAppProposeService {
    private let metadata: AppMetadata
    private let kms: KeyManagementServiceProtocol
    let linkEnvelopesDispatcher: LinkEnvelopesDispatcher

    private let logger: ConsoleLogging

    init(
        metadata: AppMetadata,
        linkEnvelopesDispatcher: LinkEnvelopesDispatcher,
        kms: KeyManagementServiceProtocol,
        logger: ConsoleLogging
    ) {
        self.metadata = metadata
        self.linkEnvelopesDispatcher = linkEnvelopesDispatcher
        self.kms = kms
        self.logger = logger
    }
    
    func propose(
        namespaces: [String: ProposalNamespace],
        optionalNamespaces: [String: ProposalNamespace]? = nil,
        sessionProperties: [String: String]? = nil,
        scopedProperties: [String: String]? = nil,
        walletUniversalLink: String
    ) async throws -> String {
        try Namespace.validate(namespaces)
        if let optionalNamespaces {
            try Namespace.validate(optionalNamespaces)
        }
        if let sessionProperties {
            try SessionProperties.validate(sessionProperties)
        }
        let protocolMethod = SessionProposeProtocolMethod.responseApprove()
        let publicKey = try! kms.createX25519KeyPair()
        let proposer = Participant(
            publicKey: publicKey.hexRepresentation,
            metadata: metadata)
        
        let proposal = SessionProposal(
            relays: [],
            proposer: proposer,
            requiredNamespaces: namespaces,
            optionalNamespaces: optionalNamespaces ?? [:],
            sessionProperties: sessionProperties,
            scopedProperties: scopedProperties
        )
        
        let request = RPCRequest(method: protocolMethod.method, params: proposal)
        let envelope = try await linkEnvelopesDispatcher.request(topic: UUID().uuidString,request: request, peerUniversalLink: walletUniversalLink, envelopeType: .type2)

        return envelope
    }
}
