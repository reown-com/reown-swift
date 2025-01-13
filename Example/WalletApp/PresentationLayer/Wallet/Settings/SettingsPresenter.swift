import UIKit
import Combine
import WalletConnectNetworking
import ReownWalletKit

final class SettingsPresenter: ObservableObject {

    private let interactor: SettingsInteractor
    private let importAccount: ImportAccount
    private let router: SettingsRouter
    private let accountStorage: AccountStorage
    private var disposeBag = Set<AnyCancellable>()
    @Published var smartAccountSafe: String = "Loading..."

    init(interactor: SettingsInteractor, router: SettingsRouter, accountStorage: AccountStorage, importAccount: ImportAccount) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
        self.accountStorage = accountStorage
        self.importAccount = importAccount
        fetchSmartAccountSafe()
    }

    func fetchSmartAccountSafe() {
        Task {
            do {
                let smartAccount = try await getSmartAccountSafe()
                DispatchQueue.main.async {
                    self.smartAccountSafe = smartAccount
                }
            } catch {
                DispatchQueue.main.async {
                    self.smartAccountSafe = "Failed to load"
                }
                print("Failed to get smart account safe: \(error)")
            }
        }
    }

    func enableSmartAccount(_ enable: Bool) {
        WalletKitEnabler.shared.isSmartAccountEnabled = enable
    }

    /// Enables or disables the 7702 Account.
    /// - Parameter enable: A Boolean value indicating whether to enable the 7702 Account.
    func enable7702Account(_ enable: Bool) {
        WalletKitEnabler.shared.is7702AccountEnabled = enable
    }

    func enableChainAbstraction(_ enable: Bool) {
        WalletKitEnabler.shared.isChainAbstractionEnabled = enable
    }

    private func getSmartAccountSafe() async throws -> String {
        try await WalletKit.instance.getSmartAccount(ownerAccount: importAccount.account).absoluteString
    }

    var account: String {
        guard let importAccount = accountStorage.importAccount else { return .empty }
        return importAccount.account.absoluteString
    }

    var privateKey: String {
        guard let importAccount = accountStorage.importAccount else { return .empty }
        return importAccount.privateKey
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

    func sendTransaction() async throws -> String {

        // hardcoded sepolia
        let ownerAccount = try! Account(blockchain: Blockchain("eip155:11155111")!, accountAddress: importAccount.account.address)

        let prepareSendTransactions = try await WalletKit.instance.prepareSendTransactions(
            [.init(
                to: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
                value: "0",
                input: "0x68656c6c6f"
            )],
            ownerAccount: ownerAccount)

        let signer = ETHSigner(importAccount: importAccount)

        let signature = try signer.signHash(prepareSendTransactions.hash)

        let ownerSignature = OwnerSignature(owner: ownerAccount.address, signature: signature)

        return try await WalletKit.instance.doSendTransaction(signatures: [ownerSignature], doSendTransactionParams: prepareSendTransactions.doSendTransactionParams, ownerAccount: ownerAccount)
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
