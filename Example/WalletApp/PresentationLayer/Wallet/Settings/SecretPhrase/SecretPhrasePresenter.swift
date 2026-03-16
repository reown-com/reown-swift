import UIKit
import WalletConnectNetworking

final class SecretPhrasePresenter: ObservableObject {

    private let accountStorage: AccountStorage
    private let stacksAccountStorage: StacksAccountStorage
    private let solanaAccountStorage: SolanaAccountStorage
    private let suiAccountStorage: SuiAccountStorage
    private let tonAccountStorage: TonAccountStorage
    private let tronAccountStorage: TronAccountStorage

    init(
        accountStorage: AccountStorage,
        solanaAccountStorage: SolanaAccountStorage = SolanaAccountStorage(),
        suiAccountStorage: SuiAccountStorage = SuiAccountStorage(),
        tonAccountStorage: TonAccountStorage = TonAccountStorage(),
        tronAccountStorage: TronAccountStorage = TronAccountStorage()
    ) {
        self.accountStorage = accountStorage
        self.stacksAccountStorage = StacksAccountStorage()
        self.solanaAccountStorage = solanaAccountStorage
        self.suiAccountStorage = suiAccountStorage
        self.tonAccountStorage = tonAccountStorage
        self.tronAccountStorage = tronAccountStorage
    }

    // MARK: - EVM

    var evmAccount: String {
        guard let importAccount = accountStorage.importAccount else { return .empty }
        return importAccount.account.absoluteString
    }

    var evmPrivateKey: String {
        guard let importAccount = accountStorage.importAccount else { return .empty }
        return importAccount.privateKey
    }

    // MARK: - Stacks

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

    // MARK: - Solana

    var solanaAddress: String {
        return solanaAccountStorage.getAddress() ?? "No Solana account"
    }

    var solanaPrivateKey: String {
        return solanaAccountStorage.getPrivateKey() ?? "No Solana private key"
    }

    // MARK: - Sui

    var suiAddress: String {
        return suiAccountStorage.getAddress() ?? "No Sui account"
    }

    var suiPrivateKey: String {
        return suiAccountStorage.getPrivateKey() ?? "No Sui private key"
    }

    // MARK: - TON

    var tonAddress: String {
        return tonAccountStorage.getAddress() ?? "No TON account"
    }

    var tonPrivateKey: String {
        return tonAccountStorage.getPrivateKey() ?? "No TON private key"
    }

    // MARK: - Tron

    var tronAddress: String {
        return tronAccountStorage.getAddress() ?? "No Tron account"
    }

    var tronPrivateKey: String {
        return tronAccountStorage.getPrivateKey() ?? "No Tron private key"
    }
}

extension SecretPhrasePresenter: SceneViewModel {}
