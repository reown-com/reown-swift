import Combine

struct ApplicationConfigurator: Configurator {

    private var publishers = Set<AnyCancellable>()

    private let app: Application

    init(app: Application) {
        self.app = app
    }

    func configure() {
        let importAccount: ImportAccount
        if let existing = app.accountStorage.importAccount {
            importAccount = existing
        } else {
            let service = WalletGenerationService(accountStorage: app.accountStorage)
            importAccount = service.generateAllWallets()
        }
        MainModule.create(app: app, importAccount: importAccount)
            .present()
    }
}
