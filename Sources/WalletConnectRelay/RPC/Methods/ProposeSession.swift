import Foundation

public struct ProposeSession: RelayRPC {
    struct Params: Codable {
        let pairingTopic: String
        let sessionProposal: String
        
        init(pairingTopic: String, sessionProposal: String) {
            self.pairingTopic = pairingTopic
            self.sessionProposal = sessionProposal
        }
    }
    
    let params: Params
    
    var method: String {
        "wc_proposeSession"
    }
}
