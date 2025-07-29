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
    private let messageSigner: MessageSigner

    var authMessages: [(String, String)] {
        guard let authRequests = sessionProposal.requests?.authentication else { return [] }
        return buildFormattedMessages(authRequests: authRequests, account: importAccount.account)
    }

    func buildFormattedMessages(authRequests: [AuthPayload], account: Account) -> [(String, String)] {
        return authRequests.enumerated().compactMap { index, authPayload in
            getCommonAndRequestedChainsIntersection(authPayload: authPayload).enumerated().compactMap { chainIndex, chain in
                guard let chainAccount = Account(blockchain: chain, address: account.address) else {
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
            let showConnected = try await interactor.approve(proposal: sessionProposal, EOAAccount: importAccount.account)
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
        let account = Account(blockchain: chain, address: importAccount.account.address)!

        let supportedAuthPayload = try WalletKit.instance.buildAuthPayload(payload: authPayload, supportedEVMChains: [Blockchain("eip155:1")!, Blockchain("eip155:137")!, Blockchain("eip155:69")!], supportedMethods: ["personal_sign", "eth_sendTransaction"])

        let SIWEmessages = try WalletKit.instance.formatAuthMessage(payload: supportedAuthPayload, account: account)

        let signature = try messageSigner.sign(message: SIWEmessages, privateKey: Data(hex: importAccount.privateKey), type: .eip191)

        let auth = try WalletKit.instance.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: account)

        return auth
    }

    private func buildAuthObjects() throws -> [AuthObject] {
        guard let authRequests = sessionProposal.requests?.authentication else { return [] }
        
        var auths = [AuthObject]()
        
        try authRequests.forEach { authPayload in
            try getCommonAndRequestedChainsIntersection(authPayload: authPayload).forEach { chain in
                let auth = try createAuthObjectForChain(chain: chain, authPayload: authPayload)
                auths.append(auth)
            }
        }
        return auths
    }

    func getCommonAndRequestedChainsIntersection(authPayload: AuthPayload) -> Set<Blockchain> {
        let requestedChains: Set<Blockchain> = Set(authPayload.chains.compactMap { Blockchain($0) })
        let supportedChains: Set<Blockchain> = [Blockchain("eip155:1")!, Blockchain("eip155:137")!]
        return requestedChains.intersection(supportedChains)
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

// MARK: - SceneViewModel
extension SessionProposalPresenter: SceneViewModel {

}
