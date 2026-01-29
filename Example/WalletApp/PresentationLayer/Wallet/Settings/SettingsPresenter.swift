import UIKit
import Combine
import WalletConnectNetworking
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
