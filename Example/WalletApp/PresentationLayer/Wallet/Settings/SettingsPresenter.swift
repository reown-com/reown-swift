import UIKit
import Combine
import WalletConnectNetworking
import WalletConnectPairing
import ReownWalletKit

final class SettingsPresenter: ObservableObject {

    private let interactor: SettingsInteractor
    private let router: SettingsRouter
    private let accountStorage: AccountStorage
    private var disposeBag = Set<AnyCancellable>()

    @Published var showImportWallet = false

    let themeManager = ThemeManager.shared

    init(interactor: SettingsInteractor, router: SettingsRouter, accountStorage: AccountStorage) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
        self.accountStorage = accountStorage
    }

    lazy var scanHandler = ScanOptionsHandler(
        onScan: { [weak self] in self?.presentScanCamera() },
        onUri: { [weak self] in self?.handleScannedOrPastedUri($0) }
    )

    var clientId: String {
        guard let clientId = try? Networking.interactor.getClientId() else { return .empty }
        return clientId
    }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }

    func secretPhrasesPressed() {
        router.presentSecretPhrase()
    }

    func importWalletPressed() {
        showImportWallet = true
    }

    func browserPressed() {
        router.presentBrowser()
    }

    /// Creates the ImportWalletPresenter for the sheet
    func makeImportWalletPresenter() -> ImportWalletPresenter {
        let service = WalletGenerationService(accountStorage: accountStorage)
        return ImportWalletPresenter(walletService: service)
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
}

// MARK: SceneViewModel

extension SettingsPresenter: SceneViewModel {

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

// MARK: Privates

private extension SettingsPresenter {

    func setupInitialState() {
        scanHandler.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &disposeBag)

        themeManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &disposeBag)
    }

    func handleScannedOrPastedUri(_ uriString: String) {
        do {
            let uri = try WalletConnectURI(uriString: uriString)
            Task { @MainActor in
                do {
                    try await WalletKit.instance.pair(uri: uri)
                } catch {
                    print("Pairing error: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Invalid URI: \(error.localizedDescription)")
        }
    }
}
