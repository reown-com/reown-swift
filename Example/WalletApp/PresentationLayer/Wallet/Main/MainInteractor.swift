import Foundation
import Combine

import ReownWalletKit
import WalletConnectNotify

final class MainInteractor {

    var sessionProposalPublisher: AnyPublisher<(proposal: Session.Proposal, context: VerifyContext?), Never> {
        return WalletKit.instance.sessionProposalPublisher
    }
    
    var sessionRequestPublisher: AnyPublisher<(request: Request, context: VerifyContext?), Never> {
        return WalletKit.instance.sessionRequestPublisher
    }
    
    var authenticateRequestPublisher: AnyPublisher<(request: AuthenticationRequest, context: VerifyContext?), Never> {
        return WalletKit.instance.authenticateRequestPublisher
    }
}
