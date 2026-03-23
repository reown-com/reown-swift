import Foundation
import ReownWalletKit

// MARK: - Active Modal

enum ActiveModal: Identifiable {
    case sessionProposal(Session.Proposal, VerifyContext?)
    case sessionRequest(Request, VerifyContext?)
    case authRequest(AuthenticationRequest, VerifyContext?)
    case pay(paymentLink: String, accounts: [String])

    var id: String {
        switch self {
        case .sessionProposal: return "sessionProposal"
        case .sessionRequest: return "sessionRequest"
        case .authRequest: return "authRequest"
        case .pay: return "pay"
        }
    }
}

// MARK: - Navigation Destinations

enum SettingsDestination: Hashable {
    case secretPhrase
    case browser
}

enum WalletDestination: Hashable {
    case connectionDetails(Session)
}

// Make Session conform to Hashable for navigation
extension Session: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(topic)
    }

    public static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.topic == rhs.topic
    }
}
