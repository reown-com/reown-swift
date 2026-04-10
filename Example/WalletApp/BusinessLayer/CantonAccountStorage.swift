import Foundation
import ReownWalletKit

struct CantonAccountStorage {
    static let partyId = "operator::1220abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678"
    static let partyIdUrlEncoded = "operator%3A%3A1220abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678"
    static let publicKeyBase64 = "q83vEjRWeJCrze8SNFZbkKvN7xI0VluQq83vEjRWeJg="
    static let cantonNamespace = "1220abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678"

    static let mainnetChainId: Blockchain = Blockchain("canton:mainnet")!
    static let devnetChainId: Blockchain = Blockchain("canton:devnet")!

    func getAddress(for chainId: Blockchain? = nil) -> String {
        return Self.partyIdUrlEncoded
    }

    func getCaip10Account(for chainId: Blockchain? = nil) -> Account? {
        let resolvedChainId = chainId ?? Self.mainnetChainId
        return Account(blockchain: resolvedChainId, address: Self.partyIdUrlEncoded)
    }
}
