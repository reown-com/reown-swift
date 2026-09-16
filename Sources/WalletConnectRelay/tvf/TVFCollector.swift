import Foundation

// MARK: - TVFCollectorProtocol

public protocol TVFCollectorProtocol {
    func collect(
        rpcMethod: String,
        rpcParams: AnyCodable,
        chainID: Blockchain,
        rpcResult: RPCResult?,
        tag: Int
    ) -> TVFData?
}

// MARK: - TVFCollector

public class TVFCollector: TVFCollectorProtocol {

    // MARK: - Tag Enum
    enum Tag: Int {
        case sessionRequest = 1108
        case sessionResponse = 1109
    }

    private let chainCollectors: [ChainTVFCollector]
    
    public init() {
        self.chainCollectors = [
            EVMTVFCollector(),
            SolanaTVFCollector(),
            AlgorandTVFCollector(),
            TronTVFCollector(),
            XRPLTVFCollector(),
            HederaTVFCollector(),
            CosmosTVFCollector(),
            NearTVFCollector(),
            BitcoinTVFCollector(),
            StacksTVFCollector(),
            SuiTVFCollector(),
            PolkadotTVFCollector(),
            TonTVFCollector(),
            StellarTVFCollector()
        ]
    }

    // MARK: - Single Public Method

    /// Collects TVF data based on the given parameters and the `tag`.
    ///
    /// - Parameters:
    ///   - rpcMethod: The RPC method (e.g., `"eth_sendTransaction"`).
    ///   - rpcParams: An `AnyCodable` containing arbitrary JSON or primitive content.
    ///   - chainID:   A `Blockchain` instance (e.g., `Blockchain("eip155:1")`).
    ///   - rpcResult: An optional `RPCResult` representing `.response(AnyCodable)` or `.error(...)`.
    ///   - tag:       Integer that should map to `.sessionRequest (1108)` or `.sessionResponse (1109)`.
    ///
    /// - Returns: `TVFData` if the tag is valid. When no chain-specific
    ///   collector supports the method, the returned `TVFData` will contain only
    ///   the provided method and chain information.
    public func collect(
        rpcMethod: String,
        rpcParams: AnyCodable,
        chainID: Blockchain,
        rpcResult: RPCResult?,
        tag: Int
    ) -> TVFData? {

        // Convert the incoming 'tag' Int into the Tag enum
        guard let theTag = Tag(rawValue: tag) else {
            return nil
        }
        
        // Find a collector that supports this method, if any
        let collector = chainCollectors.first { $0.supportsMethod(rpcMethod) }

        // Extract contract addresses if this is a request
        let contractAddresses = theTag == .sessionRequest ?
            collector?.extractContractAddresses(rpcMethod: rpcMethod, rpcParams: rpcParams) : nil

        // Parse transaction hashes if this is a response
        let txHashes: [String]?
        if theTag == .sessionResponse {
            if let collector = collector {
                txHashes = collector.parseTxHashes(rpcMethod: rpcMethod, rpcResult: rpcResult, rpcParams: rpcParams)
            } else {
                txHashes = Self.plainStringResult(rpcResult)
            }
        } else {
            txHashes = nil
        }

        return TVFData(
            rpcMethods: [rpcMethod],
            chainId: chainID,
            txHashes: txHashes,
            contractAddresses: contractAddresses
        )
    }

    // MARK: - Methods without a chain collector

    /// Signing methods (`eth_signTypedData_v4`, `personal_sign`, ...) return the signature as a plain
    /// string. It is reported as-is so signature volume stays attributable, matching the JS and Flutter
    /// SDKs. Structured results belong to dedicated collectors and are skipped here.
    private static func plainStringResult(_ rpcResult: RPCResult?) -> [String]? {
        guard let rpcResult = rpcResult, case .response(let anyCodable) = rpcResult else {
            return nil
        }
        guard let result = try? anyCodable.get(String.self), !result.isEmpty else {
            return nil
        }
        return [result]
    }
}

#if DEBUG
public class TVFCollectorMock: TVFCollectorProtocol {
    public struct CollectCall {
        let method: String
        let params: AnyCodable
        let chainID: Blockchain?
        let result: RPCResult?
        let tag: Int
    }
    
    private(set) public var collectCalls: [CollectCall] = []
    public var mockResult: TVFData?
    
    public init(mockResult: TVFData? = nil) {
        self.mockResult = mockResult
    }
    
    public func collect(
        rpcMethod: String,
        rpcParams: AnyCodable,
        chainID: Blockchain,
        rpcResult: RPCResult?,
        tag: Int
    ) -> TVFData? {
        collectCalls.append(
            CollectCall(
                method: rpcMethod,
                params: rpcParams,
                chainID: chainID,
                result: RPCResult.response(AnyCodable("")),
                tag: tag
            )
        )
        return mockResult
    }
}
#endif
