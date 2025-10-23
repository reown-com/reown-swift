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
    @Published var suiInput: String = .empty
    @Published var tonPrivateKeyBase64Input: String = .empty

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
        // Generate new Sui account when creating a new account
        interactor.generateSuiAccount()
        // Generate TON keypair
        interactor.generateTonAccount()
        importAccount(ImportAccount.new())
    }

    func onImport() {
        let account: ImportAccount
        if input.isEmpty {
            account = ImportAccount.new()
        } else {
            guard let parsed = ImportAccount(input: input) else { return input = .empty }
            account = parsed
        }
        
        // Save Solana private key only if provided
        if !solanaInput.isEmpty {
            interactor.saveSolanaPrivateKey(solanaInput)
            solanaInput = .empty
        }
        
        // Save Stacks mnemonic if provided, otherwise generate a new one
        if !stacksInput.isEmpty {
            interactor.saveStacksWallet(stacksInput)
            stacksInput = .empty
        } else {
            _ = interactor.generateAndSaveStacksWallet()
        }
        
        // Save Sui private key if provided, otherwise generate a new one
        if !suiInput.isEmpty {
            interactor.saveSuiPrivateKey(suiInput)
            suiInput = .empty
        } else {
            interactor.generateSuiAccount()
        }

        // Save TON keypair if provided (base64 32-byte seed), otherwise generate a new one
        if !tonPrivateKeyBase64Input.isEmpty {
            interactor.saveTonPrivateKey(tonPrivateKeyBase64Input)
            tonPrivateKeyBase64Input = .empty
        } else {
            interactor.generateTonAccount()
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
