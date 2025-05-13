import XCTest
@testable import ReownWalletKit
@testable import WalletConnectRelay

final class WalletServiceBuilderTests: XCTestCase {
    
    var walletServiceBuilder: WalletServiceBuilder!
    let testProjectId = "test-project"
    
    override func setUp() {
        super.setUp()
        walletServiceBuilder = WalletServiceBuilder(projectId: testProjectId)
    }
    
    override func tearDown() {
        walletServiceBuilder = nil
        super.tearDown()
    }
    
    func testBuildWalletServiceWithEmptyMethods() {
        // Arrange
        let methods: [String] = []
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        // Check the structure of the response
        XCTAssertTrue(result.contains("\"url\" : \"https://rpc.walletconnect.org/v1/wallet?projectId=test-project&st=wkca&sv=\(EnvironmentInfo.sdkName)\""))
        XCTAssertTrue(result.contains("\"methods\" : ["))
        XCTAssertTrue(result.contains("\"walletService\" : ["))
    }
    
    func testBuildWalletServiceWithSingleMethod() {
        // Arrange
        let methods = ["wallet_getAssets"]
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        XCTAssertTrue(result.contains("\"url\" : \"https://rpc.walletconnect.org/v1/wallet?projectId=test-project&st=wkca&sv=\(EnvironmentInfo.sdkName)\""))
        XCTAssertTrue(result.contains("\"methods\" : ["))
        XCTAssertTrue(result.contains("\"wallet_getAssets\""))
        XCTAssertTrue(result.contains("\"walletService\" : ["))
    }
    
    func testBuildWalletServiceWithMultipleMethods() {
        // Arrange
        let methods = ["wallet_getAssets", "wallet_signMessage", "wallet_sendTransaction"]
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        XCTAssertTrue(result.contains("\"url\" : \"https://rpc.walletconnect.org/v1/wallet?projectId=test-project&st=wkca&sv=\(EnvironmentInfo.sdkName)\""))
        XCTAssertTrue(result.contains("\"methods\" : ["))
        XCTAssertTrue(result.contains("\"wallet_getAssets\""))
        XCTAssertTrue(result.contains("\"wallet_signMessage\""))
        XCTAssertTrue(result.contains("\"wallet_sendTransaction\""))
        XCTAssertTrue(result.contains("\"walletService\" : ["))
    }
    
    func testBuildWalletServiceWithSpecialCharactersInMethods() {
        // Arrange
        let methods = ["wallet_getAssets", "method-with:special@characters"]
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        XCTAssertTrue(result.contains("\"url\" : \"https://rpc.walletconnect.org/v1/wallet?projectId=test-project&st=wkca&sv=\(EnvironmentInfo.sdkName)\""))
        XCTAssertTrue(result.contains("\"methods\" : ["))
        XCTAssertTrue(result.contains("\"wallet_getAssets\""))
        XCTAssertTrue(result.contains("\"method-with:special@characters\""))
        XCTAssertTrue(result.contains("\"walletService\" : ["))
    }
    
    func testBuildWalletServiceWithMethodsContainingQuotes() {
        // Arrange
        let methods = ["wallet_getAssets", "wallet_\"quoted\"_method"]
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        XCTAssertTrue(result.contains("\"url\" : \"https://rpc.walletconnect.org/v1/wallet?projectId=test-project&st=wkca&sv=\(EnvironmentInfo.sdkName)\""))
        XCTAssertTrue(result.contains("\"methods\" : ["))
        XCTAssertTrue(result.contains("\"wallet_getAssets\""))
        XCTAssertTrue(result.contains("\"wallet_\\\"quoted\\\"_method\""))
        XCTAssertTrue(result.contains("\"walletService\" : ["))
    }
    
    // MARK: - Linux Support
    static var allTests = [
        ("testBuildWalletServiceWithEmptyMethods", testBuildWalletServiceWithEmptyMethods),
        ("testBuildWalletServiceWithSingleMethod", testBuildWalletServiceWithSingleMethod),
        ("testBuildWalletServiceWithMultipleMethods", testBuildWalletServiceWithMultipleMethods),
        ("testBuildWalletServiceWithSpecialCharactersInMethods", testBuildWalletServiceWithSpecialCharactersInMethods),
        ("testBuildWalletServiceWithMethodsContainingQuotes", testBuildWalletServiceWithMethodsContainingQuotes)
    ]
} 