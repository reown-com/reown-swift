import Foundation

public struct ApproveSession: RelayRPC {
    struct Params: Codable {
        let pairingTopic: String
        let sessionTopic: String
        let sessionProposalResponse: String
        let sessionSettlementRequest: String
        let correlationId: RPCID?
        let approvedChains: [String]
        let approvedMethods: [String]
        let approvedEvents: [String]
        
        init(pairingTopic: String, sessionTopic: String, sessionProposalResponse: String, sessionSettlementRequest: String, correlationId: RPCID?, approvedChains: [String], approvedMethods: [String], approvedEvents: [String]) {
            self.pairingTopic = pairingTopic
            self.sessionTopic = sessionTopic
            self.sessionProposalResponse = sessionProposalResponse
            self.sessionSettlementRequest = sessionSettlementRequest
            self.correlationId = correlationId
            self.approvedChains = approvedChains
            self.approvedMethods = approvedMethods
            self.approvedEvents = approvedEvents
        }
    }
    
    let params: Params
    
    var method: String {
        "wc_approveSession"
    }
}
