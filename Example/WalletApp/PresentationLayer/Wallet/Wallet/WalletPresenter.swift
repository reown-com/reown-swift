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
    
    @Published var showPairingLoading = false {
        didSet {
            handlePairingLoadingChanged()
        }
    }
    @Published var showError = false
    @Published var errorMessage = "Error"
    @Published var showConnectedSheet = false
    
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
        router.presentConnectionDetails(session: session)
    }

    func onPasteUri() {
        router.presentPaste { [weak self] uriString in
            do {
                let uri = try WalletConnectURI(uriString: uriString)
                print("URI: \(uri)")
                self?.pair(uri: uri)
            } catch {
                self?.errorMessage = error.localizedDescription
                self?.showError.toggle()
            }
        } onError: { [weak self] error in
            print(error.localizedDescription)
            self?.router.dismiss()
        }
    }

    func sendStableCoin() {
        router.presentSendStableCoin(importAccount: importAccount)
    }

    func test7702() async {
        let testAccount = ImportAccount.new()
        ActivityIndicatorManager.shared.start()
#if DEBUG
        WalletKit.instance.set7702ForLocalInfra(address: testAccount.account.address)
#endif
        print("testing 7702")
        let chainId = Blockchain("eip155:11155111")!
        let GASigner = GasAbstractionSigner()

        let tx = Tx(data: "", from: testAccount.account.address, to: "0x23d8eE973EDec76ae91669706a587b9A4aE1361A", value: "")
        let request = try! Request(topic: "", method: "eth_sendTransaction", params: AnyCodable([tx]), chainId: chainId)

        do {
            let userOpReceipt = try await GASigner.sign(request: request, importAccount: testAccount, chainId: chainId)
            ActivityIndicatorManager.shared.stop()
            AlertPresenter.present(message: userOpReceipt.description, type: .success)
        } catch {
            print(error)
            AlertPresenter.present(message: error.localizedDescription, type: .error)
            ActivityIndicatorManager.shared.stop()
        }
    }

    func onScanUri() {
        router.presentScan { [weak self] uriString in
            do {
                let uri = try WalletConnectURI(uriString: uriString)
                print("URI: \(uri)")
                self?.pair(uri: uri)
                self?.router.dismiss()
            } catch {
                self?.errorMessage = error.localizedDescription
                self?.showError.toggle()
            }
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
    
    private func pair(uri: WalletConnectURI) {
        Task.detached(priority: .high) { @MainActor [unowned self] in
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
        return "Connections"
    }

    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .always
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

