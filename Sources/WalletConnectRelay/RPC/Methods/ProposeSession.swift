import Foundation

public struct ProposeSession: RelayRPC {
    struct Params: Codable {
        let pairingTopic: String
        let sessionProposal: String
        let attestation: String
        
        init(pairingTopic: String, sessionProposal: String, attestation: String) {
            self.pairingTopic = pairingTopic
            self.sessionProposal = sessionProposal
            self.attestation = attestation
        }
    }
    
    let params: Params
    
    var method: String {
        "wc_proposeSession"
    }
}
