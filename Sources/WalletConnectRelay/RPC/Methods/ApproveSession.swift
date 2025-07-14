import Foundation

public struct ApproveSession: RelayRPC {
    struct Params: Codable {
        let pairingTopic: String
        let sessionTopic: String
        let sessionProposalResponse: String
        let sessionSettlementRequest: String
        
        init(pairingTopic: String, sessionTopic: String, sessionProposalResponse: String, sessionSettlementRequest: String) {
            self.pairingTopic = pairingTopic
            self.sessionTopic = sessionTopic
            self.sessionProposalResponse = sessionProposalResponse
            self.sessionSettlementRequest = sessionSettlementRequest
        }
    }
    
    let params: Params
    
    var method: String {
        "wc_approveSession"
    }
}
