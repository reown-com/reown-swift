import XCTest
@testable import WalletConnectRelay

final class PolkadotTVFCollectorTests: XCTestCase {
    
    private let polkadotCollector = PolkadotTVFCollector()
    
    func testParseTxHashes_PolkadotSignTransaction_CalculatesCorrectHash() {
        let rpcMethod = "polkadot_signTransaction"
        
        let rpcParams: [String: Any] = [
            "address": "15JBFhDp1rQycRFuCtkr2VouMiWyDzh3qRUPA8STY53mdRmM",
            "transactionPayload": [
                "method": "050300c07d211d3c181df768d9d9d41df6f14f9d116d9c1906f38153b208259c315b4b02286bee",
                "specVersion": "c9550f00",
                "transactionVersion": "1a000000", 
                "genesisHash": "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
                "blockHash": "af027e6af85e62cb4673e9aab17992c7d9a5952c92b9e3f008cb5ebff5e9e120",
                "era": "f502",
                "nonce": "4c",
                "tip": "00",
                "mode": "00",
                "metadataHash": "00",
                "blockNumber": "19113af",
                "address": "15JBFhDp1rQycRFuCtkr2VouMiWyDzh3qRUPA8STY53mdRmM",
                "version": 4
            ] as [String: Any]
        ]
        
        let rpcResult: [String: Any] = [
            "id": 123456789,
            "signature": "eefafdb542b591ab8f65cb6a85a43e9f267e5129394a0d80950cc7a89b98870da1d4b90c817c546fb960ac0e8c23073a912720c970379efcdbc845924e83588e"
        ]
        
        // Test
        let result = polkadotCollector.parseTxHashes(
            rpcMethod: rpcMethod,
            rpcResult: .response(AnyCodable(any: rpcResult)),
            rpcParams: AnyCodable(any: rpcParams)
        )
        
        // Expected hash
        let expectedHash = "665cd321870f1e416dc61bac60010614d7a0892328feec468c57540b8ba1a99e"
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first, expectedHash)
    }
}
