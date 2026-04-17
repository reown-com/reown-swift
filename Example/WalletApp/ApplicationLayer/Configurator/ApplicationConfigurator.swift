import SwiftUI

struct ApplicationConfigurator: Configurator {

    private let app: Application
    private let coordinator: NavigationCoordinator

    init(app: Application, coordinator: NavigationCoordinator) {
        self.app = app
        self.coordinator = coordinator
    }

    func configure() {
        let importAccount: ImportAccount
        let service = WalletGenerationService(accountStorage: app.accountStorage)

        #if ENABLE_TEST_MODE
        // In test mode, use a pre-funded wallet if a private key is provided
        if let testKey = InputConfig.testWalletPrivateKey, !testKey.isEmpty,
           service.importEVMPrivateKey(testKey),
           let account = app.accountStorage.importAccount {
            importAccount = account
            print("🧪 [TestMode] Imported test wallet: \(account.account.address)")
        } else if let existing = app.accountStorage.importAccount {
            importAccount = existing
        } else {
            importAccount = service.generateAllWallets()
        }
        #else
        if let existing = app.accountStorage.importAccount {
            importAccount = existing
        } else {
            importAccount = service.generateAllWallets()
        }
        #endif

        precondition(Thread.isMainThread, "ApplicationConfigurator.configure() must be called on the main thread")
        MainActor.assumeIsolated {
            coordinator.importAccount = importAccount

            let rootView = AppRootView(coordinator: coordinator)
            let hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .appBackgroundPrimary
            let window = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first
            window?.rootViewController = hostingController

            coordinator.setup()
        }
    }
}
