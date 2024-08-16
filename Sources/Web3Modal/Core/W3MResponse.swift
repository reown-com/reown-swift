import Foundation

public struct W3MResponse: Codable, Equatable {
    init(id: RPCID? = RPCID(), topic: String? = nil, chainId: String? = nil, result: RPCResult) {
        self.id = id
        self.topic = topic
        self.chainId = chainId
        self.result = result
    }
    
    public let id: RPCID?
    public let topic: String?
    public let chainId: String?
    public let result: RPCResult
}
