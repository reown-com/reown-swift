import UIKit
import WalletConnectNetworking
import Combine

final class WelcomePresenter: ObservableObject {
    private let interactor: WelcomeInteractor
    private let router: WelcomeRouter
    private var disposeBag = Set<AnyCancellable>()

    @Published var input: String = .empty
    @Published var solanaInput: String = .empty
    @Published var stacksInput: String = .empty

    init(interactor: WelcomeInteractor, router: WelcomeRouter) {
        defer {
            setupInitialState()
        }
        self.interactor = interactor
        self.router = router
    }
    
    func onGetStarted() {
        // Generate and save Stacks wallet
        if let stacksWallet = interactor.generateAndSaveStacksWallet() {
            stacksInput = stacksWallet
        }
        importAccount(ImportAccount.new())
    }

    func onImport() {
        guard let account = ImportAccount(input: input)
        else { return input = .empty }
        
        // Save Solana private key if provided
        if !solanaInput.isEmpty {
            interactor.saveSolanaPrivateKey(solanaInput)
            solanaInput = .empty
        }
        
        // Save Stacks mnemonic if provided
        if !stacksInput.isEmpty {
            interactor.saveStacksWallet(stacksInput)
            stacksInput = .empty
        }
        
        importAccount(account)
    }

}

// MARK: Private functions

private extension WelcomePresenter {

    func setupInitialState() {

    }

    func importAccount(_ importAccount: ImportAccount) {
        interactor.save(importAccount: importAccount)

        router.presentWallet(importAccount: importAccount)
    }
}

// MARK: - SceneViewModel

extension WelcomePresenter: SceneViewModel {

}
