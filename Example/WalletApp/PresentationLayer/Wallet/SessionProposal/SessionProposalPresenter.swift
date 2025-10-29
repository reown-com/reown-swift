import UIKit
import Combine

import ReownWalletKit
import ReownRouter

final class SessionProposalPresenter: ObservableObject {
    enum Errors: LocalizedError {
        case noCommonChains
    }
    
    private let interactor: SessionProposalInteractor
    private let router: SessionProposalRouter

    let importAccount: ImportAccount
    let sessionProposal: Session.Proposal
    let validationStatus: VerifyContext.ValidationStatus?
    
    @Published var showError = false
    @Published var errorMessage = "Error"
    @Published var showConnectedSheet = false
    
    private var disposeBag = Set<AnyCancellable>()
    private let solanaAccountStorage = SolanaAccountStorage()
    private let messageSigner: MessageSigner

    var authMessages: [(String, String)] {
        guard let authRequests = sessionProposal.requests?.authentication else { return [] }
        return buildFormattedMessages(authRequests: authRequests, account: importAccount.account)
    }

    func buildFormattedMessages(authRequests: [AuthPayload], account: Account) -> [(String, String)] {
        return authRequests.enumerated().compactMap { index, authPayload in
            getCommonAndRequestedChainsIntersection(authPayload: authPayload).enumerated().compactMap { chainIndex, chain in
                guard chain.namespace.caseInsensitiveCompare("eip155") == .orderedSame,
                      let chainAccount = resolvedAccount(for: chain, defaultAccount: account) else {
                    return nil
                }
                guard let formattedMessage = try? WalletKit.instance.formatAuthMessage(payload: authPayload, account: chainAccount) else {
                    return nil
                }
                let messagePrefix = "Auth \(index + 1) - Message \(chainIndex + 1):"
                return (messagePrefix, formattedMessage)
            }
        }.flatMap { $0 }
    }

    init(
        interactor: SessionProposalInteractor,
        router: SessionProposalRouter,
        importAccount: ImportAccount,
        proposal: Session.Proposal,
        context: VerifyContext?,
        messageSigner: MessageSigner
    ) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
        self.sessionProposal = proposal
        self.importAccount = importAccount
        self.validationStatus = context?.validation
        self.messageSigner = messageSigner
    }
    
    @MainActor
    func onApprove() async throws {
        do {
            ActivityIndicatorManager.shared.start()
            
            // Build authentication responses if there are authentication requests
            var proposalRequestsResponses: ProposalRequestsResponses? = nil
            if sessionProposal.requests?.authentication != nil {
                let authObjects = try buildAuthObjects()
                if !authObjects.isEmpty {
                    proposalRequestsResponses = ProposalRequestsResponses(authentication: authObjects)
                }
            }
            
            let showConnected = try await interactor.approve(proposal: sessionProposal, EOAAccount: importAccount.account, proposalRequestsResponses: proposalRequestsResponses)
            showConnected ? showConnectedSheet.toggle() : router.dismiss()
            ActivityIndicatorManager.shared.stop()
        } catch {
            ActivityIndicatorManager.shared.stop()
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }

    @MainActor
    func onReject() async throws {
        do {
            ActivityIndicatorManager.shared.start()
            try await interactor.reject(proposal: sessionProposal)
            ActivityIndicatorManager.shared.stop()
            router.dismiss()
        } catch {
            ActivityIndicatorManager.shared.stop()
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }
    
    func onConnectedSheetDismiss() {
        router.dismiss()
    }

    func dismiss() {
        router.dismiss()
    }

    private func createAuthObjectForChain(chain: Blockchain, authPayload: AuthPayload) throws -> AuthObject {
        guard let account = resolvedAccount(for: chain, defaultAccount: importAccount.account) else {
            throw Errors.noCommonChains
        }

        let SIWEmessages = try WalletKit.instance.formatAuthMessage(payload: authPayload, account: account)

        let signature = try messageSigner.sign(message: SIWEmessages, privateKey: Data(hex: importAccount.privateKey), type: .eip191)

        let auth = try WalletKit.instance.buildSignedAuthObject(authPayload: authPayload, signature: signature, account: account)

        return auth
    }

    private func buildAuthObjects() throws -> [AuthObject] {
        guard let authRequests = sessionProposal.requests?.authentication else { return [] }
        
        var auths = [AuthObject]()
        
        try authRequests.forEach { authPayload in
            let evmChains = getCommonAndRequestedChainsIntersection(authPayload: authPayload).filter { $0.namespace.caseInsensitiveCompare("eip155") == .orderedSame }
            try evmChains.forEach { chain in
                let auth = try createAuthObjectForChain(chain: chain, authPayload: authPayload)
                auths.append(auth)
            }
        }
        return auths
    }

    func getCommonAndRequestedChainsIntersection(authPayload: AuthPayload) -> Set<Blockchain> {
        let requestedChains = Set(authPayload.chains.compactMap { Blockchain($0) })
        return supportedChainsIntersection(from: requestedChains)
    }
}

// MARK: - Private functions
private extension SessionProposalPresenter {
    func setupInitialState() {
        WalletKit.instance.sessionProposalExpirationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] proposal in
            guard let self = self else { return }
            if proposal.id == self.sessionProposal.id {
                dismiss()
            }
        }.store(in: &disposeBag)

        WalletKit.instance.pairingExpirationPublisher
            .receive(on: DispatchQueue.main)
            .sink {[weak self]  pairing in
                if self?.sessionProposal.pairingTopic == pairing.topic {
                    self?.dismiss()
                }
        }.store(in: &disposeBag)
    }
}

private extension SessionProposalPresenter {
    func resolvedAccount(for chain: Blockchain, defaultAccount: Account) -> Account? {
        if chain.namespace.caseInsensitiveCompare("eip155") == .orderedSame {
            return Account(blockchain: chain, address: defaultAccount.address)
        }

        if chain.namespace.caseInsensitiveCompare("solana") == .orderedSame,
           let solanaAccount = solanaAccountStorage.getCaip10Account(),
           solanaAccount.blockchain == chain {
            return solanaAccount
        }

        return nil
    }

    func supportedChainsIntersection(from requestedChains: Set<Blockchain>) -> Set<Blockchain> {
        let evmChains = requestedChains.filter { $0.namespace.caseInsensitiveCompare("eip155") == .orderedSame }
        var supported = Set(evmChains)

        if let solanaAccount = solanaAccountStorage.getCaip10Account() {
            let solanaChains = requestedChains.filter { chain in
                chain.namespace.caseInsensitiveCompare("solana") == .orderedSame &&
                chain.reference == solanaAccount.reference
            }
            supported.formUnion(solanaChains)
        }

        return supported
    }
}

// MARK: - SceneViewModel
extension SessionProposalPresenter: SceneViewModel {

}
