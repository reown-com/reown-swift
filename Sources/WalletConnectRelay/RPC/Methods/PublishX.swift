
import Foundation
import JSONRPC
import WalletConnectUtils

public struct PublishX: RelayRPC {

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

        init(topic: String, message: String, ttl: Int, prompt: Bool?, tag: Int?, correlationId: RPCID?, tvfData: TVFData?) {
            self.topic = topic
            self.message = message
            self.ttl = ttl
            self.prompt = prompt
            self.tag = tag
            self.correlationId = correlationId
            self.rpcMethods = tvfData?.rpcMethods
            self.chainId = tvfData?.chainId
            self.txHashes = tvfData?.txHashes
            self.contractAddresses = tvfData?.contractAddresses
        }
    }

    let params: Params

    var method: String {
        "irn_publish"
    }
}

