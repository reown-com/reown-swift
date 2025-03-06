import XCTest
@testable import WalletConnectSign

final class WalletServiceFinderTests: XCTestCase {
    
    var sut: WalletServiceFinder!
    var logger: ConsoleLogging!
    
    // Test data
    let mockChainId = Blockchain("eip155:1")!
    let mockMethod = "wallet_getAssets"
    
    override func setUp() {
        super.setUp()
        logger = ConsoleLogger()
        sut = WalletServiceFinder(logger: logger)
    }
    
    override func tearDown() {
        sut = nil
        logger = nil
        super.tearDown()
    }
    
    // MARK: - findWalletService Tests
    
    func testFindWalletService_WithMatchingMethodAndUrl_ReturnsURL() {
        // Arrange
        let scopedProperties = [
            "eip155:1": """
            {
                "walletService": [{
                    "url": "https://wallet-service.com",
                    "methods": ["wallet_getAssets", "wallet_getBalance"]
                }]
            }
            """
        ]
        
        // Act
        let result = sut.findWalletService(for: mockMethod, in: scopedProperties, under: "eip155:1")
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, "https://wallet-service.com")
    }
    
    func testFindWalletService_WithNonMatchingMethod_ReturnsNil() {
        // Arrange
        let scopedProperties = [
            "eip155:1": """
            {
                "walletService": [{
                    "url": "https://wallet-service.com",
                    "methods": ["different_method"]
                }]
            }
            """
        ]
        
        // Act
        let result = sut.findWalletService(for: mockMethod, in: scopedProperties, under: "eip155:1")
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testFindWalletService_WithInvalidJSON_ReturnsNil() {
        // Arrange
        let scopedProperties = [
            "eip155:1": "{ invalid json }"
        ]
        
        // Act
        let result = sut.findWalletService(for: mockMethod, in: scopedProperties, under: "eip155:1")
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testFindWalletService_WithMissingWalletService_ReturnsNil() {
        // Arrange
        let scopedProperties = [
            "eip155:1": "{ \"otherField\": [] }"
        ]
        
        // Act
        let result = sut.findWalletService(for: mockMethod, in: scopedProperties, under: "eip155:1")
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testFindWalletService_WithMultipleServices_ReturnsFirstMatching() {
        // Arrange
        let scopedProperties = [
            "eip155:1": """
            {
                "walletService": [
                    {
                        "url": "https://non-matching.com",
                        "methods": ["different_method"]
                    },
                    {
                        "url": "https://matching.com",
                        "methods": ["wallet_getAssets"]
                    },
                    {
                        "url": "https://also-matching.com",
                        "methods": ["wallet_getAssets", "wallet_getBalance"]
                    }
                ]
            }
            """
        ]
        
        // Act
        let result = sut.findWalletService(for: mockMethod, in: scopedProperties, under: "eip155:1")
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, "https://matching.com")
    }
    
    func testFindWalletService_WithInvalidURL_SkipsAndContinues() {
        // Arrange
        let scopedProperties = [
            "eip155:1": """
            {
                "walletService": [
                    {
                        "url": "invalid://\\u0000",
                        "methods": ["wallet_getAssets"]
                    },
                    {
                        "url": "https://valid-url.com",
                        "methods": ["wallet_getAssets"]
                    }
                ]
            }
            """
        ]
        
        // Act
        let result = sut.findWalletService(for: mockMethod, in: scopedProperties, under: "eip155:1")
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, "https://valid-url.com")
    }
    
    // MARK: - findMatchingWalletService Tests
    
    func testFindMatchingWalletService_WithExactChainMatch_ReturnsURL() {
        // Arrange
        let session = createMockSession(scopedProperties: [
            "eip155:1": """
            {
                "walletService": [{
                    "url": "https://exact-chain-match.com",
                    "methods": ["wallet_getAssets"]
                }]
            }
            """
        ])
        
        let request = createMockRequest(method: mockMethod, chainId: mockChainId)
        
        // Act
        let result = sut.findMatchingWalletService(for: request, in: session)
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, "https://exact-chain-match.com")
    }
    
    func testFindMatchingWalletService_WithNamespaceMatch_ReturnsURL() {
        // Arrange
        let session = createMockSession(scopedProperties: [
            "eip155": """
            {
                "walletService": [{
                    "url": "https://namespace-match.com",
                    "methods": ["wallet_getAssets"]
                }]
            }
            """
        ])
        
        let request = createMockRequest(method: mockMethod, chainId: mockChainId)
        
        // Act
        let result = sut.findMatchingWalletService(for: request, in: session)
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, "https://namespace-match.com")
    }
    
    func testFindMatchingWalletService_WithNoMatch_ReturnsNil() {
        // Arrange
        let session = createMockSession(scopedProperties: [
            "eip155:2": """
            {
                "walletService": [{
                    "url": "https://no-match.com",
                    "methods": ["wallet_getAssets"]
                }]
            }
            """
        ])
        
        let request = createMockRequest(method: mockMethod, chainId: mockChainId)
        
        // Act
        let result = sut.findMatchingWalletService(for: request, in: session)
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testFindMatchingWalletService_WithNoScopedProperties_ReturnsNil() {
        // Arrange
        let session = createMockSession(scopedProperties: nil)
        let request = createMockRequest(method: mockMethod, chainId: mockChainId)
        
        // Act
        let result = sut.findMatchingWalletService(for: request, in: session)
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testFindMatchingWalletService_PrefersExactChainMatchOverNamespace() {
        // Arrange
        let session = createMockSession(scopedProperties: [
            "eip155": """
            {
                "walletService": [{
                    "url": "https://namespace-match.com",
                    "methods": ["wallet_getAssets"]
                }]
            }
            """,
            "eip155:1": """
            {
                "walletService": [{
                    "url": "https://exact-chain-match.com",
                    "methods": ["wallet_getAssets"]
                }]
            }
            """
        ])
        
        let request = createMockRequest(method: mockMethod, chainId: mockChainId)
        
        // Act
        let result = sut.findMatchingWalletService(for: request, in: session)
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, "https://exact-chain-match.com")
    }
    
    // MARK: - Helper Methods
    
    private func createMockSession(scopedProperties: [String: String]?) -> WCSession {
        let selfPublicKey = "self_public_key"
        let peerParticipant = Participant(
            publicKey: "peer_public_key",
            metadata: AppMetadata.stub()
        )
        return WCSession(
            topic: "mock_topic",
            pairingTopic: "pairing_topic",
            timestamp: Date(),
            selfParticipant: Participant(
                publicKey: selfPublicKey,
                metadata: AppMetadata.stub()
            ),
            peerParticipant: peerParticipant,
            settleParams: SessionType.SettleParams(
                relay: RelayProtocolOptions(protocol: "irn", data: nil),
                controller: peerParticipant,
                namespaces: [:],
                sessionProperties: nil,
                scopedProperties: scopedProperties,
                expiry: Int64(Date().timeIntervalSince1970 + 86400)
            ),
            requiredNamespaces: [:],
            acknowledged: true,
            transportType: .relay,
            verifyContext: nil
        )
    }
    
    private func createMockRequest(method: String, chainId: Blockchain) -> Request {
        return try! Request(
            topic: "mock_topic",
            method: method,
            params: AnyCodable(["address": "0x1234"]),
            chainId: chainId
        )
    }
} 
