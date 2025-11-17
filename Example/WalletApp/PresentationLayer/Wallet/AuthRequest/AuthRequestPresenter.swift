import UIKit
import Combine

import ReownWalletKit
import ReownRouter
import SolanaSwift
import TweetNacl

final class AuthRequestPresenter: ObservableObject {
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
    private let router: AuthRequestRouter

    let importAccount: ImportAccount
    let request: AuthenticationRequest
    let validationStatus: VerifyContext.ValidationStatus?
    
    var messages: [(String, String)] {
        return buildFormattedMessages(request: request)
    }

    func buildFormattedMessages(request: AuthenticationRequest) -> [(String, String)] {
        getCommonAndRequestedChainsIntersection().enumerated().compactMap { index, chain in
            guard let chainAccount = resolvedAccount(for: chain) else {
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

        let messagePayload: AuthPayload
        let message: String
        let signature: CacaoSignature

        if chain.namespace.caseInsensitiveCompare("eip155") == .orderedSame {
            let evmChains = getCommonAndRequestedChainsIntersection().filter { $0.namespace.caseInsensitiveCompare("eip155") == .orderedSame }
            guard !evmChains.isEmpty else { throw Errors.noCommonChains }

            messagePayload = try WalletKit.instance.buildAuthPayload(
                payload: request.payload,
                supportedEVMChains: Array(evmChains),
                supportedMethods: ["personal_sign", "eth_sendTransaction"]
            )
            message = try WalletKit.instance.formatAuthMessage(payload: messagePayload, account: account)
            let privateKey = try dataFromHexString(importAccount.privateKey)
            signature = try messageSigner.sign(
                message: message,
                privateKey: privateKey,
                type: .eip191
            )
        } else if chain.namespace.caseInsensitiveCompare("solana") == .orderedSame {
            messagePayload = request.payload
            message = try WalletKit.instance.formatAuthMessage(payload: messagePayload, account: account)
            signature = try solanaSignature(for: message)
        } else {
            throw Errors.noCommonChains
        }

        return try WalletKit.instance.buildSignedAuthObject(authPayload: messagePayload, signature: signature, account: account)
    }

    private func buildAuthObjects() throws -> [AuthObject] {
        var auths = [AuthObject]()

        let chains = prioritizedChains(from: getCommonAndRequestedChainsIntersection())
        try chains.forEach { chain in
            let auth = try createAuthObjectForChain(chain: chain)
            auths.append(auth)
        }
        return auths
    }

    private func buildOneAuthObject() throws -> [AuthObject] {
        let chains = prioritizedChains(from: getCommonAndRequestedChainsIntersection())
        guard let chain = chains.first else { throw Errors.noCommonChains }

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

    func resolvedAccount(for chain: Blockchain) -> WalletConnectUtils.Account? {
        if chain.namespace.caseInsensitiveCompare("eip155") == .orderedSame {
            return Account(blockchain: chain, address: importAccount.account.address)
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
extension AuthRequestPresenter: SceneViewModel {

}
