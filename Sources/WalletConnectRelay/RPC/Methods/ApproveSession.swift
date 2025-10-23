import Foundation

public struct ApproveSession: RelayRPC {
    struct Params: Codable {
        let pairingTopic: String
        let sessionTopic: String
        let sessionProposalResponse: String
        let sessionSettlementRequest: String
        let correlationId: RPCID?
        let approvedChains: [String]
        
        init(pairingTopic: String, sessionTopic: String, sessionProposalResponse: String, sessionSettlementRequest: String, correlationId: RPCID?, approvedChains: [String]) {
            self.pairingTopic = pairingTopic
            self.sessionTopic = sessionTopic
            self.sessionProposalResponse = sessionProposalResponse
            self.sessionSettlementRequest = sessionSettlementRequest
            self.correlationId = correlationId
            self.approvedChains = approvedChains
        }
    }
    
    let params: Params
    
    var method: String {
        "wc_approveSession"
    }
}
