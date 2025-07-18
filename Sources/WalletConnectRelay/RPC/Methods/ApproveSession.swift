import Foundation

public struct ApproveSession: RelayRPC {
    struct Params: Codable {
        let pairingTopic: String
        let sessionTopic: String
        let sessionProposalResponse: String
        let sessionSettlementRequest: String
        let correlationId: RPCID?
        
        init(pairingTopic: String, sessionTopic: String, sessionProposalResponse: String, sessionSettlementRequest: String, correlationId: RPCID?) {
            self.pairingTopic = pairingTopic
            self.sessionTopic = sessionTopic
            self.sessionProposalResponse = sessionProposalResponse
            self.sessionSettlementRequest = sessionSettlementRequest
            self.correlationId = correlationId
        }
    }
    
    let params: Params
    
    var method: String {
        "wc_approveSession"
    }
}
