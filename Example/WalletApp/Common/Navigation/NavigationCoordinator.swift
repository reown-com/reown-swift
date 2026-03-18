import SwiftUI
import Combine
import ReownWalletKit
import WalletConnectNetworking

@MainActor
final class NavigationCoordinator: ObservableObject {

    // MARK: - Navigation State

    @Published var selectedTab: TabPage = .wallets
    @Published var activeModal: ActiveModal?
    @Published var settingsPath = NavigationPath()
    @Published var walletPath = NavigationPath()
    @Published var showScanCamera = false

    // MARK: - Dependencies

    let app: Application
    var importAccount: ImportAccount!

    // MARK: - Cached View Models (created once, reused across tab switches)

    private(set) lazy var balancesViewModel: BalancesViewModel = {
        let vm = BalancesViewModel(app: app, importAccount: importAccount)
        vm.scanHandler.onScanOverride = { [weak self] in self?.presentScanCamera() }
        return vm
    }()

    private(set) lazy var walletPresenter: WalletPresenter = {
        let p = WalletPresenter(interactor: WalletInteractor(), app: app, importAccount: importAccount)
        p.scanHandler.onScanOverride = { [weak self] in self?.presentScanCamera() }
        return p
    }()

    private(set) lazy var settingsPresenter: SettingsPresenter = {
        let p = SettingsPresenter(accountStorage: app.accountStorage)
        p.scanHandler.onScanOverride = { [weak self] in self?.presentScanCamera() }
        return p
    }()

    private var disposeBag = Set<AnyCancellable>()
    private var pendingPaymentTask: DispatchWorkItem?

    // MARK: - Init

    init(app: Application) {
        self.app = app
    }

    // MARK: - Setup

    func setup() {
        app.configurationService.configure(importAccount: importAccount)
        subscribeToWalletKit()
    }

    // MARK: - Modal Presentation

    func dismissModal() {
        activeModal = nil
    }

    func presentScanCamera() {
        showScanCamera = true
    }

    func handleScanResult(_ uriString: String) {
        showScanCamera = false

        // Check if it's a Pay URL
        if WalletKit.isPaymentLink(uriString) {
            showPayment(paymentLink: uriString)
            return
        }

        // Otherwise, try WalletConnect pairing URI
        do {
            let uri = try WalletConnectURI(uriString: uriString)
            Task {
                do {
                    try await WalletKit.instance.pair(uri: uri)
                } catch {
                    WalletToast.present(message: error.localizedDescription, type: .error)
                }
            }
        } catch {
            WalletToast.present(message: "Invalid QR code", type: .error)
        }
    }

    func showPayment(paymentLink: String) {
        let address = importAccount.account.address
        let accounts = [
            "eip155:1:\(address)",
            "eip155:137:\(address)",
            "eip155:8453:\(address)"
        ]

        if activeModal != nil {
            pendingPaymentTask?.cancel()
            activeModal = nil
            let task = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.activeModal = .pay(paymentLink: paymentLink, accounts: accounts)
            }
            pendingPaymentTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
        } else {
            activeModal = .pay(paymentLink: paymentLink, accounts: accounts)
        }
    }

    // MARK: - WalletKit Subscriptions

    private func subscribeToWalletKit() {
        // Subscribe to wallet import notifications
        NotificationCenter.default.publisher(for: .walletImported)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWalletImported()
            }
            .store(in: &disposeBag)

        // Subscribe to payment link notifications from scan handlers
        NotificationCenter.default.publisher(for: .paymentLinkDetected)
            .receive(on: DispatchQueue.main)
            .compactMap { $0.object as? String }
            .sink { [weak self] paymentLink in
                self?.showPayment(paymentLink: paymentLink)
            }
            .store(in: &disposeBag)

        WalletKit.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.activeModal = .sessionProposal(session.proposal, session.context)
            }
            .store(in: &disposeBag)

        WalletKit.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (request, context) in
                guard let self else { return }
                // Dedup: don't present if already showing a session request
                if case .sessionRequest = self.activeModal { return }
                self.dismissModal()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.activeModal = .sessionRequest(request, context)
                }
            }
            .store(in: &disposeBag)

        WalletKit.instance.authenticateRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                let requestedChains: Set<Blockchain> = Set(result.request.payload.chains.compactMap { Blockchain($0) })
                let supportedChains: Set<Blockchain> = [Blockchain("eip155:1")!, Blockchain("eip155:137")!]
                let commonChains = requestedChains.intersection(supportedChains)
                guard !commonChains.isEmpty else {
                    WalletToast.present(message: "No common chains", type: .error)
                    return
                }
                self?.activeModal = .authRequest(result.request, result.context)
            }
            .store(in: &disposeBag)
    }

    private func handleWalletImported() {
        // Disconnect all active WalletConnect sessions
        let sessions = WalletKit.instance.getSessions()
        for session in sessions {
            Task {
                try? await WalletKit.instance.disconnect(topic: session.topic)
            }
        }

        // Refresh balances
        Task { await balancesViewModel.refresh() }
    }
}
