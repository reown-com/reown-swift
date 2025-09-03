import Foundation

import ReownWalletKit
import ReownRouter
import WalletConnectSign
import WalletConnectYttrium

final class SessionProposalRustInteractor {
    func approve(proposal: WalletConnectYttrium.Session.Proposal, EOAAccount: Account) async throws -> Bool {
        
        // Compute supported sets from proposal
        let supportedMethods = Set(proposal.requiredNamespaces.flatMap { $0.value.methods } + (proposal.optionalNamespaces?.flatMap { $0.value.methods } ?? []))
        let supportedEvents = Set(proposal.requiredNamespaces.flatMap { $0.value.events } + (proposal.optionalNamespaces?.flatMap { $0.value.events } ?? []))
        
        let supportedRequiredChains = proposal.requiredNamespaces["eip155"]?.chains ?? []
        let supportedOptionalChains = proposal.optionalNamespaces?["eip155"]?.chains ?? []
        let supportedChains = supportedRequiredChains + supportedOptionalChains

        // Build supported accounts for AutoNamespaces
        let supportedAccounts: [Account] = Array(supportedChains).compactMap { chainId in
            Account(chainIdentifier: chainId.absoluteString, address: EOAAccount.address)
        }

        // 1) Build WalletConnectSign session namespaces using AutoNamespaces
        let wcSessionNamespaces = try AutoNamespaces.build(
            requiredNamespaces: proposal.requiredNamespaces,
            optionalNamespaces: proposal.optionalNamespaces,
            chains: supportedChains,
            methods: Array(supportedMethods),
            events: Array(supportedEvents),
            accounts: supportedAccounts
        )

        // 2) Convert to Rust SettleNamespace shape
        let approvedNamespaces: [String: SettleNamespace] = wcSessionNamespaces.reduce(into: [:]) { acc, element in
            let (key, ns) = element
            let accounts = ns.accounts.map { $0.absoluteString }
            let methods = Array(ns.methods)
            let events = Array(ns.events)
            let chains = (ns.chains ?? []).map { $0.absoluteString }
            acc[key] = SettleNamespace(accounts: accounts, methods: methods, events: events, chains: chains)
        }
        
        // Self metadata for this wallet (mirrors app configuration)
        let metadata = try WalletConnectYttrium.AppMetadata(
            name: "Example Wallet",
            description: "wallet description",
            url: "example.wallet",
            icons: ["https://avatars.githubusercontent.com/u/37784886"],
            redirect: AppMetadata.Redirect(native: "walletapp://", universal: "https://lab.web3modal.com/wallet", linkMode: true)
        )
        
        _ = try await WalletKitRust.instance.approve(
            proposal,
            approvedNamespaces: approvedNamespaces,
            selfMetadata: metadata
        )
        
        // TODO: Handle redirect if needed (proposal might have redirect info)
        // For now, always show connected sheet
        return true
    }

    func reject(proposal: WalletConnectYttrium.Session.Proposal) async throws {
        // TODO: Implement reject functionality in WalletKitRust
        // For now, we can't reject through the Rust client
        try await WalletKitRust.instance.reject(proposal, reason: .userRejected)
    }
}


