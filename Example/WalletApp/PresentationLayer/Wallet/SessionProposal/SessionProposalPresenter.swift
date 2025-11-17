import UIKit
import Combine

import ReownWalletKit
import ReownRouter
import SolanaSwift
import TweetNacl
import WalletConnectUtils

final class SessionProposalPresenter: ObservableObject {
    enum Errors: LocalizedError {
        case noCommonChains
        case solanaAccountUnavailable
        case invalidPrivateKey

        var errorDescription: String? {
            switch self {
            case .noCommonChains:
                return "No supported chains available for this authentication request."
            case .solanaAccountUnavailable:
                return "Solana account is not available. Please create or import a Solana account."
            case .invalidPrivateKey:
                return "Unable to read the signing key for this account."
            }
        }
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

    func buildFormattedMessages(authRequests: [AuthPayload], account: WalletConnectUtils.Account) -> [(String, String)] {
        return authRequests.enumerated().compactMap { index, authPayload in
            getCommonAndRequestedChainsIntersection(authPayload: authPayload).enumerated().compactMap { chainIndex, chain in
                guard let chainAccount = resolvedAccount(for: chain, defaultAccount: account) else {
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

        let message = try WalletKit.instance.formatAuthMessage(payload: authPayload, account: account)
        let signature: CacaoSignature

        if chain.namespace.caseInsensitiveCompare("eip155") == .orderedSame {
            let privateKey = try dataFromHexString(importAccount.privateKey)
            signature = try messageSigner.sign(
                message: message,
                privateKey: privateKey,
                type: .eip191
            )
        } else if chain.namespace.caseInsensitiveCompare("solana") == .orderedSame {
            signature = try solanaSignature(for: message)
        } else {
            throw Errors.noCommonChains
        }

        return try WalletKit.instance.buildSignedAuthObject(authPayload: authPayload, signature: signature, account: account)
    }

    private func buildAuthObjects() throws -> [AuthObject] {
        guard let authRequests = sessionProposal.requests?.authentication else { return [] }
        
        var auths = [AuthObject]()
        
        try authRequests.forEach { authPayload in
            let chains = prioritizedChains(from: getCommonAndRequestedChainsIntersection(authPayload: authPayload))
            try chains.forEach { chain in
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
    func resolvedAccount(for chain: Blockchain, defaultAccount: WalletConnectUtils.Account) -> WalletConnectUtils.Account? {
        if chain.namespace.caseInsensitiveCompare("eip155") == .orderedSame {
            return Account(blockchain: chain, address: defaultAccount.address)
        }

        if chain.namespace.caseInsensitiveCompare("solana") == .orderedSame,
           let solanaAccount = solanaAccountStorage.getCaip10Account() {
            return Account(blockchain: chain, address: solanaAccount.address)
        }

        return nil
    }

    func supportedChainsIntersection(from requestedChains: Set<Blockchain>) -> Set<Blockchain> {
        let evmChains = requestedChains.filter { $0.namespace.caseInsensitiveCompare("eip155") == .orderedSame }
        var supported = Set(evmChains)

        if solanaAccountStorage.getCaip10Account() != nil {
            let solanaChains = requestedChains.filter { chain in
                chain.namespace.caseInsensitiveCompare("solana") == .orderedSame
            }
            supported.formUnion(solanaChains)
        }

        return supported
    }

    func prioritizedChains(from chains: Set<Blockchain>) -> [Blockchain] {
        chains.sorted { lhs, rhs in
            let lhsPriority = chainPriority(lhs)
            let rhsPriority = chainPriority(rhs)
            if lhsPriority == rhsPriority {
                return lhs.absoluteString < rhs.absoluteString
            }
            return lhsPriority < rhsPriority
        }
    }

    func chainPriority(_ chain: Blockchain) -> Int {
        switch chain.namespace.lowercased() {
        case "eip155": return 0
        case "solana": return 1
        default: return 2
        }
    }

    func solanaSignature(for message: String) throws -> CacaoSignature {
        guard
            let privateKey = solanaAccountStorage.getPrivateKey(),
            let messageData = message.data(using: .utf8)
        else { throw Errors.solanaAccountUnavailable }

        let secretKey = Data(SolanaSwift.Base58.decode(privateKey))
        let signatureBytes = try NaclSign.signDetached(message: messageData, secretKey: secretKey)
        let signature = SolanaSwift.Base58.encode(Array(signatureBytes))
        return CacaoSignature(t: .ed25519, s: signature)
    }

    func dataFromHexString(_ hex: String) throws -> Data {
        var cleaned = hex
        if cleaned.hasPrefix("0x") { cleaned.removeFirst(2) }
        guard cleaned.count % 2 == 0 else { throw Errors.invalidPrivateKey }

        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard nextIndex <= cleaned.endIndex else { throw Errors.invalidPrivateKey }
            let byteString = cleaned[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { throw Errors.invalidPrivateKey }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}

// MARK: - SceneViewModel
extension SessionProposalPresenter: SceneViewModel {

}
