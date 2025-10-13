import Foundation

import WalletConnectSign

enum Proposal {
    static let namespaces: [String: ProposalNamespace] = [
        "solana": ProposalNamespace(
            chains: [
                Blockchain("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")!
            ],
            methods: [
                "solana_signMessage",
                "solana_signTransaction"
            ], events: []
        ),
        "eip155": ProposalNamespace(
            chains: [
                Blockchain("eip155:137")!,
                Blockchain("eip155:10")!
            ],
            methods: [
                "eth_sendTransaction",
                "personal_sign",
                "eth_signTypedData"
            ], events: []
        )
    ]
}

struct Chain {
    let name: String
    let id: String
}

final class SignInteractor {}
