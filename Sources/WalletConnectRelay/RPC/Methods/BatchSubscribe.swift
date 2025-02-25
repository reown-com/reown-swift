
import Foundation

struct BatchSubscribe: RelayRPC {

    struct Params: Codable {
        let topics: [String]
    }
    let chainId: Blockchain! = nil
    init(params: Params) {
        self.params = params
    }

    let params: Params

    var method: String {
        "irn_batchSubscribe"
    }
}

