import UIKit
import Combine

import ReownAppKit
import WalletConnectSign

final class SignPresenter: ObservableObject {
    @Published var accountsDetails = [AccountDetails]()
    
    @Published var showError = false
    @Published var errorMessage = String.empty
    
    var walletConnectUri: WalletConnectURI?
    
    let chains = [
        Chain(name: "Ethereum", id: "eip155:1"),
        Chain(name: "Polygon", id: "eip155:137"),
        Chain(name: "Solana", id: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
    ]
    
    private let interactor: SignInteractor
    private let router: SignRouter

    private var session: Session?
    private let authSignatureVerifier = AuthSignatureVerifier()
    
    private var subscriptions = Set<AnyCancellable>()

    init(
        interactor: SignInteractor,
        router: SignRouter
    ) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
    }
    
    func onAppear() {
        
    }
    
    func copyUri() {
        UIPasteboard.general.string = walletConnectUri?.absoluteString
    }
    
    func connectWalletWithW3M() {
        Task {
            AppKit.set(sessionParams: .init(
                namespaces: Proposal.namespaces
            ))
        }
        AppKit.present(from: nil)
    }

    @MainActor
    func connectWalletWithSessionPropose() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()
                walletConnectUri = try await Sign.instance.connect(
                    namespaces: Proposal.namespaces,
                    authentication: [.stub()]
                )
                ActivityIndicatorManager.shared.stop()
                router.presentNewPairing(walletConnectUri: walletConnectUri!)
            } catch {
                ActivityIndicatorManager.shared.stop()
            }
        }
    }

    @MainActor
    func connectWalletWithSessionAuthenticate() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()
                let uri = try await Sign.instance.authenticate(.stub())
                walletConnectUri = uri
                ActivityIndicatorManager.shared.stop()
                router.presentNewPairing(walletConnectUri: walletConnectUri!)
            } catch {
                ActivityIndicatorManager.shared.stop()
            }
        }
    }

    @MainActor
    func connectWalletWithWalletPay() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()
                walletConnectUri = try await Sign.instance.connect(
                    namespaces: Proposal.namespaces,
                    walletPay: .stub()
                )
                ActivityIndicatorManager.shared.stop()
                router.presentNewPairing(walletConnectUri: walletConnectUri!)
            } catch {
                ActivityIndicatorManager.shared.stop()
            }
        }
    }

    @MainActor
    func connectWalletWithSessionAuthenticateSIWEOnly() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()
                let uri = try await Sign.instance.authenticate(.stub(methods: ["personal_sign"]))
                walletConnectUri = uri
                ActivityIndicatorManager.shared.stop()
                router.presentNewPairing(walletConnectUri: walletConnectUri!)
            } catch {
                ActivityIndicatorManager.shared.stop()
            }
        }
    }

    @MainActor
    func connectWalletWithSessionAuthenticateLinkMode() {
        Task {
            do {
                ActivityIndicatorManager.shared.start()
                if let pairingUri = try await Sign.instance.authenticate(.stub(methods: ["personal_sign"]), walletUniversalLink: "https://lab.web3modal.com/wallet") {
                    walletConnectUri = pairingUri
                    ActivityIndicatorManager.shared.stop()
                    router.presentNewPairing(walletConnectUri: walletConnectUri!)
                }
            } catch {
                AlertPresenter.present(message: error.localizedDescription, type: .error)
                ActivityIndicatorManager.shared.stop()
            }
        }
    }

    @MainActor
    func openConfiguration() {
        router.openConfig()
    }

    @MainActor
    func disconnect() {
        if let session {
            Task { @MainActor in
                do {
                    ActivityIndicatorManager.shared.start()
                    try await Sign.instance.disconnect(topic: session.topic)
                    ActivityIndicatorManager.shared.stop()
                    accountsDetails.removeAll()
                } catch {
                    ActivityIndicatorManager.shared.stop()
                    showError.toggle()
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func presentSessionAccount(sessionAccount: AccountDetails) {
        if let session {
            router.presentSessionAccount(sessionAccount: sessionAccount, session: session)
        }
    }
}

// MARK: - Private functions
extension SignPresenter {
    private func setupInitialState() {
        getSession()
        
        Sign.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] _ in
                self.accountsDetails.removeAll()
                router.popToRoot()
                Task(priority: .high) { ActivityIndicatorManager.shared.stop() }
            }
            .store(in: &subscriptions)

        Sign.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] session, responses in
                if let authResponses = responses?.authentication {
                    print("DApp: Session settled with \(authResponses.count) authentication responses")
                    
                    // Verify authentication signatures individually
                    Task {
                        var verifiedCount = 0
                        var verificationErrors: [String] = []
                        var verifiedChains: [String] = []
                        
                        for (index, authObject) in authResponses.enumerated() {
                            do {
                                try await authSignatureVerifier.recoverAndVerifySignature(authObject: authObject)
                                verifiedCount += 1
                                
                                // Extract chain from the issuer (did:pkh:chainId:address)
                                if let account = try? DIDPKH(did: authObject.p.iss).account {
                                    verifiedChains.append(account.blockchainIdentifier)
                                }
                                
                                print("DApp: Verified auth response \(index + 1) from: \(authObject.p.iss)")
                            } catch {
                                let errorMsg = "Auth \(index + 1) failed: \(error.localizedDescription)"
                                verificationErrors.append(errorMsg)
                                print("DApp: \(errorMsg)")
                            }
                        }
                        
                        // Display verification results with chain information
                        let totalCount = authResponses.count
                        let chainsText = verifiedChains.isEmpty ? "" : " on chains: \(verifiedChains.joined(separator: ", "))"
                        
                        if verifiedCount == totalCount {
                            AlertPresenter.present(message: "Verified \(verifiedCount) of \(totalCount) signatures\(chainsText)", type: .success)
                        } else {
                            let errorDetails = verificationErrors.joined(separator: "\n")
                            AlertPresenter.present(message: "⚠️ Verified only \(verifiedCount) of \(totalCount) signatures\(chainsText)\n\(errorDetails)", type: .warning)
                        }
                        
                        print("DApp: Verification complete - \(verifiedCount)/\(totalCount) signatures verified on chains: \(verifiedChains.joined(separator: ", "))")
                    }
                } else {
                    print("DApp: Session settled without authentication responses")
                }
                self.getSession()
            }
            .store(in: &subscriptions)

        Sign.instance.authResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] response in
                switch response.result {
                case .success(let (session, _)):
                    if session == nil {
                        AlertPresenter.present(message: "Wallet Succesfully Authenticated", type: .success)
                    } else {
                        self.router.dismiss()
                        self.getSession()
                    }
                    break
                case .failure(let error):
                    AlertPresenter.present(message: error.localizedDescription, type: .error)
                }
                Task(priority: .high) { ActivityIndicatorManager.shared.stop() }
            }
            .store(in: &subscriptions)

        Sign.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { response in
                Task(priority: .high) { ActivityIndicatorManager.shared.stop() }
            }
            .store(in: &subscriptions)

        Sign.instance.requestExpirationPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task(priority: .high) { ActivityIndicatorManager.shared.stop() }
                AlertPresenter.present(message: "Session Request has expired", type: .warning)
            }
            .store(in: &subscriptions)

        AppKit.instance.SIWEAuthenticationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] result in
                switch result {
                case .success((let message, let signature)):
                    AlertPresenter.present(message: "Authenticated with SIWE", type: .success)
                    self.router.dismiss()
                    self.getSession()
                case .failure(let error):
                    AlertPresenter.present(message: "\(error)", type: .warning)
                }
            }
            .store(in: &subscriptions)
    }
    
    private func getSession() {
        if let session = Sign.instance.getSessions().first {
            self.session = session
            session.namespaces.values.forEach { namespace in
                namespace.accounts.forEach { account in
                    accountsDetails.append(
                        AccountDetails(
                            chain: account.blockchainIdentifier,
                            methods: Array(namespace.methods),
                            address: account.address
                        )
                    )
                }
            }
        }
    }
}

// MARK: - SceneViewModel
extension SignPresenter: SceneViewModel {}


// MARK: - Authenticate request stub
extension AuthRequestParams {
    static func stub(
        domain: String = "lab.web3modal.com",
        chains: [String] = ["eip155:1", "eip155:137"],
        nonce: String = "32891756",
        uri: String = "https://lab.web3modal.com",
        nbf: String? = nil,
        exp: String? = nil,
        statement: String? = "I accept the ServiceOrg Terms of Service: https://app.web3inbox.com/tos",
        requestId: String? = nil,
        resources: [String]? = nil,
        methods: [String]? = ["personal_sign", "eth_sendTransaction"]
    ) -> AuthRequestParams {
        return try! AuthRequestParams(
            domain: domain,
            chains: chains,
            nonce: nonce,
            uri: uri,
            nbf: nbf,
            exp: exp,
            statement: statement,
            requestId: requestId,
            resources: resources,
            methods: methods
        )
    }
}

// MARK: - WalletPay request stub
extension WalletPayParams {
    static func stub(
        version: String = "1.0",
        orderId: String? = "order_12345_test",
        expiry: UInt64 = UInt64(Date().timeIntervalSince1970) + 3600 // 1 hour from now
    ) -> WalletPayParams {
        let usdcPayment = PaymentOption(
            asset: "USDC",
            amount: "0x1BC16D674EC80000", // 2 USDC in hex
            recipient: "0x742d35Cc6634C0532925a3b8D400e4e7c61B1234"
        )
        
        let usdtPayment = PaymentOption(
            asset: "USDT",
            amount: "0x1BC16D674EC80000", // 2 USDT in hex (same value as USDC)
            recipient: "0x742d35Cc6634C0532925a3b8D400e4e7c61B1234"
        )
        
        return WalletPayParams(
            version: version,
            orderId: orderId,
            acceptedPayments: [usdcPayment, usdtPayment],
            expiry: expiry
        )
    }
}
