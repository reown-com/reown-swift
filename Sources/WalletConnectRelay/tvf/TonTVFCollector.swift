import Foundation

// MARK: - TonTVFCollector

class TonTVFCollector: ChainTVFCollector {
    // MARK: - Constants
    static let TON_SEND_MESSAGE = "ton_sendMessage"

    // MARK: - Supported Methods
    private var supportedMethods: [String] {
        [Self.TON_SEND_MESSAGE]
    }

    func supportsMethod(_ method: String) -> Bool {
        return supportedMethods.contains(method)
    }

    // MARK: - Implementation
    func extractContractAddresses(rpcMethod: String, rpcParams: AnyCodable) -> [String]? {
        // TON collector does not extract contract addresses
        return nil
    }

    func parseTxHashes(rpcMethod: String, rpcResult: RPCResult?, rpcParams: AnyCodable?) -> [String]? {
        // If rpcResult is nil or is an error, we can't parse anything
        guard let rpcResult = rpcResult, case .response(let anycodable) = rpcResult else {
            return nil
        }

        guard supportedMethods.contains(rpcMethod) else {
            return nil
        }

        // Follow TonSigner response shape: a top-level object containing { "boc": "..." }
        if let outer = try? anycodable.get([String: AnyCodable].self),
           let boc = outer["boc"],
           let bocStr = try? boc.get(String.self) {
            return [bocStr]
        }

        return nil
    }
}


