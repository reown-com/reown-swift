import SwiftUI
import Combine
import WalletConnectNetworking
import ReownWalletKit

final class SettingsPresenter: ObservableObject {

    let accountStorage: AccountStorage
    private var disposeBag = Set<AnyCancellable>()

    @Published var showImportWallet = false

    let themeManager = ThemeManager.shared

    lazy var scanHandler = ScanOptionsHandler(
        onScan: { [weak self] in self?.presentScanCamera() },
        onUri: { [weak self] in self?.handleScannedOrPastedUri($0) }
    )

    init(accountStorage: AccountStorage) {
        self.accountStorage = accountStorage
        setupInitialState()
    }

    var clientId: String {
        guard let clientId = try? Networking.interactor.getClientId() else { return .empty }
        return clientId
    }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }

    func importWalletPressed() {
        showImportWallet = true
    }

    func makeImportWalletPresenter() -> ImportWalletPresenter {
        let service = WalletGenerationService(accountStorage: accountStorage)
        return ImportWalletPresenter(walletService: service)
    }

    private func presentScanCamera() {
        // Scan camera still uses UIKit bridge via ScanOptionsHandler
    }
}

// MARK: - Privates

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
