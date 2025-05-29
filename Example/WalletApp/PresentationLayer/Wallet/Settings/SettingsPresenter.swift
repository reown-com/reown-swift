import UIKit
import Combine
import WalletConnectNetworking
import ReownWalletKit

final class SettingsPresenter: ObservableObject {

    private let interactor: SettingsInteractor
    private let importAccount: ImportAccount
    private let router: SettingsRouter
    private let accountStorage: AccountStorage
    private let solanaAccountStorage: SolanaAccountStorage
    private let suiAccountStorage: SuiAccountStorage
    private var disposeBag = Set<AnyCancellable>()

    init(interactor: SettingsInteractor, router: SettingsRouter, accountStorage: AccountStorage, importAccount: ImportAccount, solanaAccountStorage: SolanaAccountStorage = SolanaAccountStorage(), suiAccountStorage: SuiAccountStorage = SuiAccountStorage()) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
        self.accountStorage = accountStorage
        self.importAccount = importAccount
        self.solanaAccountStorage = solanaAccountStorage
        self.suiAccountStorage = suiAccountStorage
    }

    func enableChainAbstraction(_ enable: Bool) {
        WalletKitEnabler.shared.isChainAbstractionEnabled = enable
    }

    var account: String {
        guard let importAccount = accountStorage.importAccount else { return .empty }
        return importAccount.account.absoluteString
    }

    var privateKey: String {
        guard let importAccount = accountStorage.importAccount else { return .empty }
        return importAccount.privateKey
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

    var clientId: String {
        guard let clientId = try? Networking.interactor.getClientId() else { return .empty }
        return clientId
    }

    var deviceToken: String {
        guard let deviceToken = UserDefaults.standard.string(forKey: "deviceToken") else { return .empty }
        return deviceToken
    }

    func browserPressed() {
        router.presentBrowser()
    }

    func logoutPressed() async throws {
        guard let account = accountStorage.importAccount?.account else { return }
        try? await interactor.notifyUnregister(account: account)
        accountStorage.importAccount = nil
        try await WalletKit.instance.cleanup()
        UserDefaults.standard.set(nil, forKey: "deviceToken")
        await router.presentWelcome()
    }
}

// MARK: SceneViewModel

extension SettingsPresenter: SceneViewModel {

    var sceneTitle: String? {
        return "Settings"
    }

    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .always
    }
}

// MARK: Privates

private extension SettingsPresenter {

    func setupInitialState() {

    }
}
