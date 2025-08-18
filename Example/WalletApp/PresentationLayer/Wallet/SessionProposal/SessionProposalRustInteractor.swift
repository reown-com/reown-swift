import Foundation

import ReownWalletKit
import ReownRouter
import YttriumWrapper

final class SessionProposalRustInteractor {
    func approve(proposal: SessionProposalFfi, EOAAccount: Account) async throws -> Bool {
        // Use WalletKitRust for approval
        let approvedSession = try await WalletKitRust.instance.approve(proposal, approvedNamespaces: [String : SettleNamespace], selfMetadata: <#T##Metadata#>)
        
        // TODO: Handle redirect if needed (proposal might have redirect info)
        // For now, always show connected sheet
        return true
    }

    func reject(proposal: SessionProposalFfi) async throws {
        // TODO: Implement reject functionality in WalletKitRust
        // For now, we can't reject through the Rust client
        throw NSError(domain: "SessionProposalRustInteractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Reject not yet implemented for Rust client"])
    }
} 
