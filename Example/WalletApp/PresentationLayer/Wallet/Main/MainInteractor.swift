import Foundation
import Combine

import ReownWalletKit
import WalletConnectNotify
import WalletConnectYttrium

final class MainInteractor {

    var sessionProposalPublisher: AnyPublisher<(proposal: WalletConnectYttrium.Session.Proposal, context: VerifyContext?), Never> {
        return WalletKitRust.instance.sessionProposalPublisher
    }
    
    var sessionRequestPublisher: AnyPublisher<(request: Request, context: VerifyContext?), Never> {
        return WalletKitRust.instance.sessionRequestPublisher
    }
    
    var authenticateRequestPublisher: AnyPublisher<(request: AuthenticationRequest, context: VerifyContext?), Never> {
        return WalletKit.instance.authenticateRequestPublisher
    }
}
