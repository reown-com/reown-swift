import UIKit
import Combine

import ReownWalletKit

final class WalletPresenter: ObservableObject {
    enum Errors: LocalizedError {
        case invalidUri(uri: String)
    }
    
    private let interactor: WalletInteractor
    private let router: WalletRouter
    private let importAccount: ImportAccount
    
    private let app: Application
    private var isPairingTimer: Timer?

    @Published var sessions = [Session]()
    @Published var selectedSessionForDetail: Session? = nil
    @Published var isDisconnecting = false

    @Published var showPairingLoading = false {
        didSet {
            handlePairingLoadingChanged()
        }
    }
    @Published var showError = false
    @Published var errorMessage = "Error"
    @Published var showConnectedSheet = false
    @Published var showScanOptions = false
    
    private var disposeBag = Set<AnyCancellable>()

    init(
        interactor: WalletInteractor,
        router: WalletRouter,
        app: Application,
        importAccount: ImportAccount
    ) {
        defer {
            setupInitialState()
        }
        self.interactor = interactor
        self.router = router
        self.app = app
        self.importAccount = importAccount
    }
    
    func onAppear() {
        showPairingLoading = app.requestSent
        setUpPairingIndicatorRemoval()

        let pendingRequests = interactor.getPendingRequests()
        if let request = pendingRequests.first(where: { $0.context != nil }) {
            router.present(sessionRequest: request.request, importAccount: importAccount, sessionContext: request.context)
        }
    }
    
    func onConnection(session: Session) {
        selectedSessionForDetail = session
    }

    func disconnectSelectedSession() {
        guard let session = selectedSessionForDetail else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isDisconnecting = true
            do {
                try await self.interactor.disconnectSession(session: session)
                self.isDisconnecting = false
                self.selectedSessionForDetail = nil
            } catch {
                self.isDisconnecting = false
                AlertPresenter.present(message: error.localizedDescription, type: .error)
            }
        }
    }

    func onScanOptions() {
        showScanOptions = true
    }

    func onScanQR() {
        showScanOptions = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.presentScanCamera()
        }
    }

    func onPasteURL() {
        let clipboard = UIPasteboard.general.string ?? ""
        guard !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AlertPresenter.present(message: "No URL found in clipboard", type: .warning)
            return
        }
        showScanOptions = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.handleScannedOrPastedUri(clipboard)
        }
    }

    private func presentScanCamera() {
        router.presentScan { [weak self] uriString in
            self?.router.dismiss()
            self?.handleScannedOrPastedUri(uriString)
        } onError: { [weak self] error in
            print(error.localizedDescription)
            self?.router.dismiss()
        }
    }
    
    func removeSession(at indexSet: IndexSet) async {
        if let index = indexSet.first {
            do {
                ActivityIndicatorManager.shared.start()
                try await interactor.disconnectSession(session: sessions[index])
                ActivityIndicatorManager.shared.stop()
            } catch {
                ActivityIndicatorManager.shared.stop()
                sessions = sessions
                AlertPresenter.present(message: error.localizedDescription, type: .error)
            }
        }
    }

    private func handlePairingLoadingChanged() {
        isPairingTimer?.invalidate()

        if showPairingLoading {
            isPairingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                AlertPresenter.present(message: "Pairing takes longer then expected, check your internet connection or try again", type: .warning)
            }
        }
    }
}

// MARK: - Private functions
extension WalletPresenter {
    private func setupInitialState() {
        interactor.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.sessions = sessions
            }
            .store(in: &disposeBag)
        
        sessions = interactor.getSessions()
        
        pairFromDapp()
    }
    
    /// Handle scanned or pasted URI - detect if it's a Pay URL or WalletConnect pairing URI
    private func handleScannedOrPastedUri(_ uriString: String) {
        // Check if it's a WalletConnect Pay URL
        if WalletKit.isPaymentLink(uriString) {
            print("Detected WalletConnect Pay URL: \(uriString)")
            router.startPayFlow(paymentLink: uriString, importAccount: importAccount)
            return
        }

        // Otherwise, try to parse as WalletConnect pairing URI
        do {
            let uri = try WalletConnectURI(uriString: uriString)
            print("URI: \(uri)")
            pair(uri: uri)
        } catch {
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }
    
    private func pair(uri: WalletConnectURI) {
        Task(priority: .high) { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.interactor.pair(uri: uri)
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError.toggle()
            }
        }
    }
    
    private func pairFromDapp() {
        guard let uri = app.uri else {
            return
        }
        pair(uri: uri)
    }

    private func setUpPairingIndicatorRemoval() {
        WalletKit.instance.pairingStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPairing in
            self?.showPairingLoading = isPairing
        }.store(in: &disposeBag)
    }
}

// MARK: - SceneViewModel
extension WalletPresenter: SceneViewModel {
    var sceneTitle: String? {
        return nil
    }

    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .never
    }

    var isNavigationBarHidden: Bool {
        return true
    }
}

// MARK: - LocalizedError
extension WalletPresenter.Errors {
    var errorDescription: String? {
        switch self {
        case .invalidUri(let uri):  return "URI invalid format\n\(uri)"
        }
    }
}

