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
    
    private func compareJsonObjects(_ actual: String, _ expected: String) {
        // Parse both strings to dictionaries
        let actualData = actual.data(using: .utf8)!
        let expectedData = expected.data(using: .utf8)!
        
        let actualDict = try! JSONSerialization.jsonObject(with: actualData, options: []) as! [String: Any]
        let expectedDict = try! JSONSerialization.jsonObject(with: expectedData, options: []) as! [String: Any]
        
        // Get walletService array from both dictionaries
        let actualService = (actualDict["walletService"] as! [[String: Any]])[0]
        let expectedService = (expectedDict["walletService"] as! [[String: Any]])[0]
        
        // Compare url
        let actualUrl = actualService["url"] as! String
        let expectedUrl = expectedService["url"] as! String
        
        // Only compare the projectId part, not the entire URL which has SDK version
        XCTAssertTrue(actualUrl.contains("projectId=\(testProjectId)"), "URL should contain correct projectId")
        XCTAssertTrue(actualUrl.contains("&st=wkca&sv="), "URL should contain correct parameters")
        
        // Compare methods array
        let actualMethods = actualService["methods"] as! [String]
        let expectedMethods = expectedService["methods"] as! [String]
        XCTAssertEqual(actualMethods, expectedMethods, "Methods array should match expected")
    }
    
    func testBuildWalletServiceWithEmptyMethods() {
        // Arrange
        let methods: [String] = []
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        let expectedUrl = "https://rpc.walletconnect.org/v1/wallet?projectId=\(testProjectId)&st=wkca&sv=\(EnvironmentInfo.sdkName)"
        let expected = """
        {
            "walletService": [{
                "url": "\(expectedUrl)",
                "methods": []
            }]
        }
        """
        
        compareJsonObjects(result, expected)
    }
    
    func testBuildWalletServiceWithSingleMethod() {
        // Arrange
        let methods = ["wallet_getAssets"]
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        let expectedUrl = "https://rpc.walletconnect.org/v1/wallet?projectId=\(testProjectId)&st=wkca&sv=\(EnvironmentInfo.sdkName)"
        let expected = """
        {
            "walletService": [{
                "url": "\(expectedUrl)",
                "methods": ["wallet_getAssets"]
            }]
        }
        """
        
        compareJsonObjects(result, expected)
    }
    
    func testBuildWalletServiceWithMultipleMethods() {
        // Arrange
        let methods = ["wallet_getAssets", "wallet_signMessage", "wallet_sendTransaction"]
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        let expectedUrl = "https://rpc.walletconnect.org/v1/wallet?projectId=\(testProjectId)&st=wkca&sv=\(EnvironmentInfo.sdkName)"
        let expected = """
        {
            "walletService": [{
                "url": "\(expectedUrl)",
                "methods": ["wallet_getAssets", "wallet_signMessage", "wallet_sendTransaction"]
            }]
        }
        """
        
        compareJsonObjects(result, expected)
    }
    
    func testBuildWalletServiceWithSpecialCharactersInMethods() {
        // Arrange
        let methods = ["wallet_getAssets", "method-with:special@characters"]
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        let expectedUrl = "https://rpc.walletconnect.org/v1/wallet?projectId=\(testProjectId)&st=wkca&sv=\(EnvironmentInfo.sdkName)"
        let expected = """
        {
            "walletService": [{
                "url": "\(expectedUrl)",
                "methods": ["wallet_getAssets", "method-with:special@characters"]
            }]
        }
        """
        
        compareJsonObjects(result, expected)
    }
    
    func testBuildWalletServiceWithMethodsContainingQuotes() {
        // Arrange
        let methods = ["wallet_getAssets", "wallet_quoted_method"]
        
        // Act
        let result = walletServiceBuilder.buildWalletService(methods)
        
        // Assert
        let expectedUrl = "https://rpc.walletconnect.org/v1/wallet?projectId=\(testProjectId)&st=wkca&sv=\(EnvironmentInfo.sdkName)"
        let expected = """
        {
            "walletService": [{
                "url": "\(expectedUrl)",
                "methods": ["wallet_getAssets", "wallet_quoted_method"]
            }]
        }
        """
        
        compareJsonObjects(result, expected)
    }
} 
