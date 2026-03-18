import UIKit
import Combine

import ReownWalletKit

final class WalletPresenter: ObservableObject {
    enum Errors: LocalizedError {
        case invalidUri(uri: String)
    }
    
    private let interactor: WalletInteractor
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
@Published var showConnectedSheet = false

    lazy var scanHandler = ScanOptionsHandler(
        onScan: { [weak self] in self?.presentScanCamera() },
        onUri: { [weak self] in self?.handleScannedOrPastedUri($0) }
    )
    
    private var disposeBag = Set<AnyCancellable>()

    init(
        interactor: WalletInteractor,
        app: Application,
        importAccount: ImportAccount
    ) {
        defer {
            setupInitialState()
        }
        self.interactor = interactor
        self.app = app
        self.importAccount = importAccount
    }
    
    func onAppear() {
        showPairingLoading = app.requestSent
        setUpPairingIndicatorRemoval()

        // Pending requests are handled by NavigationCoordinator's WalletKit subscriptions
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
                WalletToast.present(message: error.localizedDescription, type: .error)
            }
        }
    }

    private func presentScanCamera() {
        // Scan camera handled via ScanOptionsHandler sheet
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
                WalletToast.present(message: error.localizedDescription, type: .error)
            }
        }
    }

    private func handlePairingLoadingChanged() {
        isPairingTimer?.invalidate()

        if showPairingLoading {
            isPairingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                WalletToast.present(message: "Pairing takes longer then expected, check your internet connection or try again", type: .warning)
            }
        }
    }
}

// MARK: - Private functions
extension WalletPresenter {
    private func setupInitialState() {
        scanHandler.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &disposeBag)

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
        // Check if it's a WalletConnect Pay URL — handled via notification
        if WalletKit.isPaymentLink(uriString) {
            print("Detected WalletConnect Pay URL: \(uriString)")
            // Post notification for coordinator to handle
            NotificationCenter.default.post(name: .paymentLinkDetected, object: uriString)
            return
        }

        // Otherwise, try to parse as WalletConnect pairing URI
        do {
            let uri = try WalletConnectURI(uriString: uriString)
            print("URI: \(uri)")
            pair(uri: uri)
        } catch {
            WalletToast.present(message: "Invalid link or URI", type: .error)
        }
    }

    private func pair(uri: WalletConnectURI) {
        Task(priority: .high) { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.interactor.pair(uri: uri)
            } catch {
                WalletToast.present(message: error.localizedDescription, type: .error)
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


// MARK: - LocalizedError
extension WalletPresenter.Errors {
    var errorDescription: String? {
        switch self {
        case .invalidUri(let uri):  return "URI invalid format\n\(uri)"
        }
    }
}

