import UIKit
import WalletConnectNetworking
import Combine
import HDWalletKit

final class WelcomePresenter: ObservableObject {
    private let interactor: WelcomeInteractor
    private let router: WelcomeRouter
    private var disposeBag = Set<AnyCancellable>()

    @Published var mnemonicInput: String = .empty
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
        // Generate new Solana, Sui, TON, and Tron accounts when creating a new account
        interactor.generateSolanaAccount()
        interactor.generateSuiAccount()
        interactor.generateTonAccount()
        interactor.generateTronAccount()
        importAccount(ImportAccount.new())
    }

    func onImport() {
        let account: ImportAccount

        // If mnemonic is provided, derive the Ethereum private key from it
        if !mnemonicInput.isEmpty {
            let trimmed = mnemonicInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let seed = Mnemonic.createSeed(mnemonic: trimmed)
            // BIP44 Ethereum derivation path: m/44'/60'/0'/0/0
            let masterKey = PrivateKey(seed: seed, coin: .ethereum)
            let derived = masterKey
                .derived(at: .hardened(44))
                .derived(at: .hardened(60))
                .derived(at: .hardened(0))
                .derived(at: .notHardened(0))
                .derived(at: .notHardened(0))
            let hexKey = derived.raw.toHexString()
            guard let parsed = ImportAccount(input: hexKey) else {
                mnemonicInput = .empty
                return
            }
            account = parsed
            mnemonicInput = .empty
        } else if input.isEmpty {
            account = ImportAccount.new()
        } else {
            guard let parsed = ImportAccount(input: input) else { return input = .empty }
            account = parsed
        }
        
        // Save Solana private key only if provided
        if !solanaInput.isEmpty {
            interactor.saveSolanaPrivateKey(solanaInput)
            solanaInput = .empty
        } else {
            interactor.generateSolanaAccount()
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

        // Always generate Tron account (no import UI)
        interactor.generateTronAccount()

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
