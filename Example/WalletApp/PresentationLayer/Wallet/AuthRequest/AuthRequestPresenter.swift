import UIKit
import Combine

import ReownWalletKit
import ReownRouter

final class AuthRequestPresenter: ObservableObject {
    enum Errors: LocalizedError {
        case noCommonChains
    }
    private let router: AuthRequestRouter

    let importAccount: ImportAccount
    let request: AuthenticationRequest
    let validationStatus: VerifyContext.ValidationStatus?
    
    var messages: [(String, String)] {
        return buildFormattedMessages(request: request)
    }

    func buildFormattedMessages(request: AuthenticationRequest) -> [(String, String)] {
        getCommonAndRequestedChainsIntersection().enumerated().compactMap { index, chain in
            guard chain.namespace.caseInsensitiveCompare("eip155") == .orderedSame,
                  let chainAccount = resolvedAccount(for: chain) else {
                return nil
            }
            guard let formattedMessage = try? WalletKit.instance.formatAuthMessage(payload: request.payload, account: chainAccount) else {
                return nil
            }
            let messagePrefix = "Message \(index + 1):"
            return (messagePrefix, formattedMessage)
        }
    }

    @Published var showSignedSheet = false
    
    private var disposeBag = Set<AnyCancellable>()
    private let solanaAccountStorage = SolanaAccountStorage()

    private let messageSigner: MessageSigner

    init(
        importAccount: ImportAccount,
        router: AuthRequestRouter,
        request: AuthenticationRequest,
        context: VerifyContext?,
        messageSigner: MessageSigner
    ) {
        defer { setupInitialState() }
        self.router = router
        self.importAccount = importAccount
        self.request = request
        self.validationStatus = context?.validation
        self.messageSigner = messageSigner
    }

    @MainActor
    func signMulti() async {
        do {
            ActivityIndicatorManager.shared.start()

            let auths = try buildAuthObjects()

            _ = try await WalletKit.instance.approveSessionAuthenticate(requestId: request.id, auths: auths)
            ActivityIndicatorManager.shared.stop()
            /* Redirect */
            if let uri = request.requester.redirect?.native {
                ReownRouter.goBack(uri: uri)
                router.dismiss()
            } else {
                showSignedSheet.toggle()
            }

        } catch {
            ActivityIndicatorManager.shared.stop()
            AlertPresenter.present(message: error.localizedDescription, type: .error)
        }
    }

    @MainActor
    func signOne() async {
        do {
            ActivityIndicatorManager.shared.start()

            let auths = try buildOneAuthObject()

            _ = try await WalletKit.instance.approveSessionAuthenticate(requestId: request.id, auths: auths)
            ActivityIndicatorManager.shared.stop()

            /* Redirect */
            if let uri = request.requester.redirect?.native {
                ReownRouter.goBack(uri: uri)
                router.dismiss()
            } else {
                showSignedSheet.toggle()
            }

        } catch {
            ActivityIndicatorManager.shared.stop()
            AlertPresenter.present(message: error.localizedDescription, type: .error)
        }
    }

    @MainActor
    func reject() async  {
        ActivityIndicatorManager.shared.start()

        do {
            try await WalletKit.instance.rejectSession(requestId: request.id)

            /* Redirect */
            if let uri = request.requester.redirect?.native {
                ReownRouter.goBack(uri: uri)
            }
            ActivityIndicatorManager.shared.stop()

            router.dismiss()
        } catch {
            ActivityIndicatorManager.shared.stop()

            AlertPresenter.present(message: error.localizedDescription, type: .error)
        }
    }
    
    func onSignedSheetDismiss() {
        router.dismiss()
    }

    private func createAuthObjectForChain(chain: Blockchain) throws -> AuthObject {
        guard let account = resolvedAccount(for: chain) else {
            throw Errors.noCommonChains
        }

        let evmChains = getCommonAndRequestedChainsIntersection().filter { $0.namespace.caseInsensitiveCompare("eip155") == .orderedSame }
        guard !evmChains.isEmpty else {
            throw Errors.noCommonChains
        }

        let supportedAuthPayload = try WalletKit.instance.buildAuthPayload(
            payload: request.payload,
            supportedEVMChains: Array(evmChains),
            supportedMethods: ["personal_sign", "eth_sendTransaction"]
        )

        let SIWEmessages = try WalletKit.instance.formatAuthMessage(payload: supportedAuthPayload, account: account)

        let signature = try messageSigner.sign(message: SIWEmessages, privateKey: Data(hex: importAccount.privateKey), type: .eip191)

        let auth = try WalletKit.instance.buildSignedAuthObject(authPayload: supportedAuthPayload, signature: signature, account: account)

        return auth
    }

    private func buildAuthObjects() throws -> [AuthObject] {
        var auths = [AuthObject]()

        let evmChains = getCommonAndRequestedChainsIntersection().filter { $0.namespace.caseInsensitiveCompare("eip155") == .orderedSame }
        try evmChains.forEach { chain in
            let auth = try createAuthObjectForChain(chain: chain)
            auths.append(auth)
        }
        return auths
    }

    private func buildOneAuthObject() throws -> [AuthObject] {
        guard let chain = getCommonAndRequestedChainsIntersection().first(where: { $0.namespace.caseInsensitiveCompare("eip155") == .orderedSame }) else {
            throw Errors.noCommonChains
        }

        let auth = try createAuthObjectForChain(chain: chain)
        return [auth]
    }


    func getCommonAndRequestedChainsIntersection() -> Set<Blockchain> {
        let requestedChains = Set(request.payload.chains.compactMap { Blockchain($0) })
        return supportedChainsIntersection(from: requestedChains)
    }

    func dismiss() {
        router.dismiss()
    }
}

// MARK: - Private functions
private extension AuthRequestPresenter {
    func setupInitialState() {
        WalletKit.instance.requestExpirationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requestId in
                guard let self = self else { return }
                if requestId == request.id {
                    dismiss()
                }
            }.store(in: &disposeBag)
    }

    func resolvedAccount(for chain: Blockchain) -> Account? {
        if chain.namespace.caseInsensitiveCompare("eip155") == .orderedSame {
            return Account(blockchain: chain, address: importAccount.account.address)
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
extension AuthRequestPresenter: SceneViewModel {

}
