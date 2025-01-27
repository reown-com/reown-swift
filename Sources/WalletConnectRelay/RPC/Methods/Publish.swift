
import Foundation
import WalletConnectUtils

struct Publish: RelayRPC {

    struct Params: Codable {
        let topic: String
        let message: String
        let ttl: Int
        let prompt: Bool?
        let tag: Int?
        
        let correlationId: RPCID?
        let rpcMethods: [String]?
        let chainId: Blockchain?
        let txHashes: [String]?
        let contractAddresses: [String]?

        init(topic: String, message: String, ttl: Int, prompt: Bool?, tag: Int?, correlationId: RPCID? = nil, rpcMethods: [String]? = nil, chainId: Blockchain? = nil, txHashes: [String]? = nil, contractAddresses: [String]? = nil) {
            self.topic = topic
            self.message = message
            self.ttl = ttl
            self.prompt = prompt
            self.tag = tag
            self.correlationId = correlationId
            self.rpcMethods = rpcMethods
            self.chainId = chainId
            self.txHashes = txHashes
            self.contractAddresses = contractAddresses
        }
    }

    let params: Params

    var method: String {
        "irn_publish"
    }
}

