import Foundation

import ReownWalletKit
import WalletConnectSign
import ReownRouter

final class SessionProposalInteractor {
    func approve(proposal: Session.Proposal, EOAAccount: Account, proposalRequestsResponses: ProposalRequestsResponses? = nil) async throws -> Bool {
        // Following properties are used to support all the required and optional namespaces for the testing purposes
        let supportedMethods = Set(proposal.requiredNamespaces.flatMap { $0.value.methods } + (proposal.optionalNamespaces?.flatMap { $0.value.methods } ?? []))
        let supportedEvents = Set(proposal.requiredNamespaces.flatMap { $0.value.events } + (proposal.optionalNamespaces?.flatMap { $0.value.events } ?? []))

        let stacksAccountStorage = StacksAccountStorage()
        let suiAccountStorage = SuiAccountStorage()
        let tonAccountStorage = TonAccountStorage()

        // Handle EIP155 chains
        let supportedRequiredChains = proposal.requiredNamespaces["eip155"]?.chains ?? []
        let supportedOptionalChains = proposal.optionalNamespaces?["eip155"]?.chains ?? []
        var supportedEIP155Chains = supportedRequiredChains + supportedOptionalChains

        // Handle Stacks chains
        let supportedRequiredStacksChains = proposal.requiredNamespaces["stacks"]?.chains ?? []
        let supportedOptionalStacksChains = proposal.optionalNamespaces?["stacks"]?.chains ?? []
        let supportedStacksChains = supportedRequiredStacksChains + supportedOptionalStacksChains

        // Handle Sui chains
        let supportedRequiredSuiChains = proposal.requiredNamespaces["sui"]?.chains ?? []
        let supportedOptionalSuiChains = proposal.optionalNamespaces?["sui"]?.chains ?? []
        let supportedSuiChains = supportedRequiredSuiChains + supportedOptionalSuiChains

        // Handle TON chains
        let supportedRequiredTonChains = proposal.requiredNamespaces["ton"]?.chains ?? []
        let supportedOptionalTonChains = proposal.optionalNamespaces?["ton"]?.chains ?? []
        let supportedTonChains = supportedRequiredTonChains + supportedOptionalTonChains

        // Combine all supported chains
        var supportedChains = supportedEIP155Chains + supportedStacksChains + supportedSuiChains + supportedTonChains

        var supportedAccounts: [Account] = []
        var sessionProperties = [String: String]()

        // Add EIP155 accounts
        let eip155Accounts = Array(supportedEIP155Chains).map { Account(blockchain: $0, address: EOAAccount.address)! }
        supportedAccounts.append(contentsOf: eip155Accounts)

        // Add Stacks accounts if available
        if !supportedStacksChains.isEmpty {
            var stacksAccounts: [Account] = []
            for chain in supportedStacksChains {
                if let stacksAccount = try stacksAccountStorage.getCaip10Account(for: chain) {
                    stacksAccounts.append(stacksAccount)
                }
            }
            supportedAccounts.append(contentsOf: stacksAccounts)
        }

        // Add Sui accounts if available
        if let suiAccount = suiAccountStorage.getCaip10Account(), !supportedSuiChains.isEmpty {
            let suiAccounts = Array(supportedSuiChains).map { Account(blockchain: $0, address: suiAccount.address)! }
            supportedAccounts.append(contentsOf: suiAccounts)
        }

        // Add TON accounts if available
        if !supportedTonChains.isEmpty {
            var tonAccounts: [Account] = []
            for chain in supportedTonChains {
                if let tonAccount = tonAccountStorage.getCaip10Account(for: chain) {
                    tonAccounts.append(tonAccount)
                }
            }
            supportedAccounts.append(contentsOf: tonAccounts)
        }

        /* Use only supported values for production. I.e:
         let supportedMethods = ["eth_signTransaction", "personal_sign", "eth_signTypedData", "eth_sendTransaction", "eth_sign"]
         let supportedEvents = ["accountsChanged", "chainChanged"]
         let supportedChains = [Blockchain("eip155:1")!, Blockchain("eip155:137")!]
         let supportedAccounts = [Account(blockchain: Blockchain("eip155:1")!, address: ETHSigner.address)!, Account(blockchain: Blockchain("eip155:137")!, address: ETHSigner.address)!]
         */

        // Define scopedProperties according to CAIP-345
        let scopedProperties: [String: String] = [
            "eip155": """
            {
                "walletService": [{
                    "url": "https://rpc.walletconnect.org/v1/wallet?projectId=\(InputConfig.projectId)&st=wkca&sv=\(EnvironmentInfo.sdkName)",
                    "methods": ["wallet_getAssets"]
                }]
            }
            """
        ]

        var sessionNamespaces: [String: SessionNamespace]!

        do {
            sessionNamespaces = try AutoNamespaces.build(
                sessionProposal: proposal,
                chains: Array(supportedChains),
                methods: Array(supportedMethods),
                events: Array(supportedEvents),
                accounts: supportedAccounts
            )
        } catch let error as AutoNamespacesError {
            try await reject(proposal: proposal, reason: RejectionReason(from: error))
            AlertPresenter.present(message: error.localizedDescription, type: .error)
            return false
        } catch {
            try await reject(proposal: proposal, reason: .userRejected)
            AlertPresenter.present(message: error.localizedDescription, type: .error)
            return false
        }

        _ = try await WalletKit.instance.approve(proposalId: proposal.id, namespaces: sessionNamespaces, sessionProperties: sessionProperties, scopedProperties: scopedProperties, proposalRequestsResponses: proposalRequestsResponses)
        if let uri = proposal.proposer.redirect?.native {
            ReownRouter.goBack(uri: uri)
            return false
        } else {
            return true
        }
    }

    func reject(proposal: Session.Proposal, reason: RejectionReason = .userRejected) async throws {
        try await WalletKit.instance.rejectSession(proposalId: proposal.id, reason: .userRejected)
        /* Redirect */
        if let uri = proposal.proposer.redirect?.native {
            ReownRouter.goBack(uri: uri)
        }
    }

    private func getSessionProperties(addresses: [String]) -> [String: String] {
        var addressCapabilities: [String] = []

        // Iterate over the addresses and construct JSON strings for each address
        for address in addresses {
            let capability = """
            "\(address)":{
                "0xaa36a7":{
                    "atomicBatch":{
                        "supported":true
                    }
                }
            }
            """
            addressCapabilities.append(capability)
        }

        // Join all the address capabilities into one JSON-like structure
        let sepoliaAtomicBatchCapabilities = "{\(addressCapabilities.joined(separator: ","))}"

        let sessionProperties: [String: String] = [
            "bundler_name": "pimlico",
            "capabilities": sepoliaAtomicBatchCapabilities
        ]

        print(sessionProperties)
        return sessionProperties
    }
}

