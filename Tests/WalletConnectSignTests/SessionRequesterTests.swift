import XCTest
@testable import WalletConnectSign
@testable import TestingUtils
@testable import WalletConnectUtils

final class SessionRequesterTests: XCTestCase {
    // SUT
    var sut: SessionRequester!
    
    // Mocks
    var sessionStoreMock: WCSessionStorageMock!
    var networkingMock: NetworkingInteractorMock!
    var loggerMock: ConsoleLoggerMock!
    var tvfCollectorMock: TVFCollectorMock!
    var walletServiceRequesterMock: WalletServiceSessionRequesterMock!
    var walletServiceFinder: WalletServiceFinder!
    
    // Test data
    let mockTopic = "mock_topic"
    let mockChainId = Blockchain("eip155:1")!
    let mockMethod = "wallet_getAssets"
    let mockParams = AnyCodable(["address": "0x1234"])
    let mockId = RPCID("123")
    
    override func setUp() {
        super.setUp()
        
        // Initialize mocks
        sessionStoreMock = WCSessionStorageMock()
        networkingMock = NetworkingInteractorMock()
        loggerMock = ConsoleLoggerMock()
        tvfCollectorMock = TVFCollectorMock()
        walletServiceRequesterMock = WalletServiceSessionRequesterMock()
        
        // Initialize real WalletServiceFinder
        walletServiceFinder = WalletServiceFinder(logger: loggerMock)
        
        // Initialize SUT with mocks and real WalletServiceFinder
        sut = SessionRequester(
            sessionStore: sessionStoreMock,
            networkingInteractor: networkingMock,
            logger: loggerMock,
            tvfCollector: tvfCollectorMock,
            walletServiceRequester: walletServiceRequesterMock,
            walletServiceFinder: walletServiceFinder
        )
    }
    
    override func tearDown() {
        sut = nil
        sessionStoreMock = nil
        networkingMock = nil
        loggerMock = nil
        tvfCollectorMock = nil
        walletServiceRequesterMock = nil
        walletServiceFinder = nil
        super.tearDown()
    }
    
    func testRequest_DelegatesToWalletServiceRequester_WhenMatchingServiceExists() async throws {
        // Arrange
        let mockWalletService = """
        {
            "walletService": [{
                "url": "https://example.com",
                "methods": ["wallet_getAssets"]
            }]
        }
        """
        
        // Create accounts for the namespace
        let accounts = [Account(blockchain: mockChainId, address: "0x1234")!]
        
        // Create namespaces that include our test method
        let namespaces = [
            "eip155": SessionNamespace(
                chains: [mockChainId],
                accounts: accounts,
                methods: [mockMethod],
                events: ["chainChanged"]
            )
        ]
        
        let mockSession = WCSession.stub(
            topic: mockTopic,
            namespaces: namespaces,
            scopedProperties: ["eip155:1": mockWalletService]
        )
        sessionStoreMock.setSession(mockSession)
        
        let request = try! Request(
            topic: mockTopic,
            method: mockMethod,
            params: mockParams,
            chainId: mockChainId
        )
        
        // Act
        try await sut.request(request)
        
        // Assert
        XCTAssertTrue(walletServiceRequesterMock.requestWasCalled, "Should delegate to walletServiceRequester")
        XCTAssertEqual(walletServiceRequesterMock.requestCalls.count, 1)
        XCTAssertEqual(walletServiceRequesterMock.requestCalls.first?.url.absoluteString, "https://example.com")
        XCTAssertFalse(networkingMock.didCallRequest, "Should not call networking request")
    }
    
    func testRequest_DelegatesToNetworking_WhenNoMatchingServiceExists() async throws {
        // Arrange
        // Create accounts for the namespace
        let accounts = [Account(blockchain: mockChainId, address: "0x1234")!]
        
        // Create namespaces that include our test method
        let namespaces = [
            "eip155": SessionNamespace(
                chains: [mockChainId],
                accounts: accounts,
                methods: [mockMethod],
                events: ["chainChanged"]
            )
        ]
        
        let mockSession = WCSession.stub(
            topic: mockTopic,
            namespaces: namespaces
        )
        sessionStoreMock.setSession(mockSession)
        
        let request = try! Request(
            topic: mockTopic,
            method: mockMethod,
            params: mockParams,
            chainId: mockChainId
        )
        
        // Act
        try await sut.request(request)
        
        // Assert
        XCTAssertFalse(walletServiceRequesterMock.requestWasCalled, "Should not delegate to walletServiceRequester")
        XCTAssertTrue(networkingMock.didCallRequest, "Should call networking request")
    }
}
