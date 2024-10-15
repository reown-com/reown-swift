import Foundation

extension WalletKit {
    struct Config {
        let crypto: CryptoProvider
        let bundlerUrl: String?
        let rpcUrl: String?
    }
}
