import UIKit
import Combine
import WalletConnectNetworking
import WalletConnectPairing
import ReownWalletKit

final class SettingsPresenter: ObservableObject {

    private let interactor: SettingsInteractor
    private let importAccount: ImportAccount
    private let router: SettingsRouter
    private let accountStorage: AccountStorage
    private let stacksAccountStorage: StacksAccountStorage
    private let solanaAccountStorage: SolanaAccountStorage
    private let suiAccountStorage: SuiAccountStorage
    private let tonAccountStorage: TonAccountStorage
    private let tronAccountStorage: TronAccountStorage
    private var disposeBag = Set<AnyCancellable>()

    init(interactor: SettingsInteractor, router: SettingsRouter, accountStorage: AccountStorage, importAccount: ImportAccount, solanaAccountStorage: SolanaAccountStorage = SolanaAccountStorage(), suiAccountStorage: SuiAccountStorage = SuiAccountStorage(), tonAccountStorage: TonAccountStorage = TonAccountStorage(), tronAccountStorage: TronAccountStorage = TronAccountStorage()) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
        self.accountStorage = accountStorage
        self.importAccount = importAccount
        self.stacksAccountStorage = StacksAccountStorage()
        self.solanaAccountStorage = solanaAccountStorage
        self.suiAccountStorage = suiAccountStorage
        self.tonAccountStorage = tonAccountStorage
        self.tronAccountStorage = tronAccountStorage
    }

    var account: String {
        guard let importAccount = accountStorage.importAccount else { return .empty }
        return importAccount.account.absoluteString
    }

    var privateKey: String {
        guard let importAccount = accountStorage.importAccount else { return .empty }
        return importAccount.privateKey
    }
    
    var stacksMnemonic: String {
        return stacksAccountStorage.getWallet() ?? .empty
    }
    
    var stacksMainnetAddress: String {
        do {
            return try stacksAccountStorage.getMainnetAddress() ?? "No Stacks mainnet address"
        } catch {
            return "Error getting Stacks mainnet address"
        }
    }
    
    var stacksTestnetAddress: String {
        do {
            return try stacksAccountStorage.getTestnetAddress() ?? "No Stacks testnet address"
        } catch {
            return "Error getting Stacks testnet address"
        }
    }

    var solanaAddress: String {
        return solanaAccountStorage.getAddress() ?? "No Solana account"
    }

    var solanaPrivateKey: String {
        return solanaAccountStorage.getPrivateKey() ?? "No Solana private key"
    }

    var suiAddress: String {
        return suiAccountStorage.getAddress() ?? "No Sui account"
    }

    var suiPrivateKey: String {
        return suiAccountStorage.getPrivateKey() ?? "No Sui private key"
    }

    var tonAddress: String {
        return tonAccountStorage.getAddress() ?? "No TON account"
    }

    var tonPrivateKey: String {
        return tonAccountStorage.getPrivateKey() ?? "No TON private key"
    }

    var tronAddress: String {
        return tronAccountStorage.getAddress() ?? "No Tron account"
    }

    var tronPrivateKey: String {
        return tronAccountStorage.getPrivateKey() ?? "No Tron private key"
    }

    var clientId: String {
        guard let clientId = try? Networking.interactor.getClientId() else { return .empty }
        return clientId
    }

    func browserPressed() {
        router.presentBrowser()
    }

    func onScanOptions() {
        router.presentScannerOptions(
            onScanQR: { [weak self] in
                self?.router.dismissToPresent {
                    self?.presentScanCamera()
                }
            },
            onPasteURL: { [weak self] in
                guard let self else { return }
                let clipboard = UIPasteboard.general.string ?? ""
                guard !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    AlertPresenter.present(message: "No URL found in clipboard", type: .warning)
                    return
                }
                self.router.dismissToPresent {
                    self.handleScannedOrPastedUri(clipboard)
                }
            }
        )
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

    func logoutPressed() async throws {
        accountStorage.importAccount = nil
        try await WalletKit.instance.cleanup()
        await router.presentWelcome()
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
