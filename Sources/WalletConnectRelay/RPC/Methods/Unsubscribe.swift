
import Foundation

struct Unsubscribe: RelayRPC {

    struct Params: Codable {
        let topic: String
    }

    let params: Params

    var method: String {
        "irn_unsubscribe"
    }
}

