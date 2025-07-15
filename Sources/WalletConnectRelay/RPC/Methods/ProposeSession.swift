import Foundation

public struct ProposeSession: RelayRPC {
    struct Params: Codable {
        let pairingTopic: String
        let sessionProposal: String
        let correlationId: RPCID?
        
        init(pairingTopic: String, sessionProposal: String, correlationId: RPCID?) {
            self.pairingTopic = pairingTopic
            self.sessionProposal = sessionProposal
            self.correlationId = correlationId
        }
    }
    
    let params: Params
    
    var method: String {
        "wc_proposeSession"
    }
}
