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
        if let existing = app.accountStorage.importAccount {
            importAccount = existing
        } else {
            let service = WalletGenerationService(accountStorage: app.accountStorage)
            importAccount = service.generateAllWallets()
        }

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
