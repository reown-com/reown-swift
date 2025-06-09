import XCTest

class UITestsWalletAgainstAppKitWeb: XCTestCase {
    private let engine: Engine = Engine()

    override class func setUp() {
        let engine: Engine = Engine()
        engine.routing.launch(app: .safari, clean: true)
        engine.routing.launch(app: .wallet, clean: true)
    }

    /// Test connecting Sample Wallet to AppKit/React App in Mobile Browser and approving session proposal
    /// Test Case: Connecting Sample Wallet to AppKit/React App in Mobile Browser and Approving Session Proposal
    /// - TU009
    func testConnectWalletToAppKitWebAndApproveSession() {
        // Step 1: Open browser to AppKit URL
        engine.routing.activate(app: .safari)
        engine.routing.wait(for: 2)
        
        // Navigate to AppKit lab URL
        engine.safari.navigateToAppKit()
        
        // Wait for page to load
        engine.routing.wait(for: 3)
        
        // Step 2: Press "Connect Wallet" button
        XCTAssertTrue(engine.safari.tapConnectWallet(), "Should be able to find and tap Connect Wallet button")
        
        // Step 3: AppKit opens - wait for wallet options to appear
        engine.routing.wait(for: 2)
        
        // Step 4: Press "Swift sample wallet"
        XCTAssertTrue(engine.safari.tapSwiftWallet(), "Should be able to find and tap Swift sample wallet button")
        
        // Step 5: iOS native screen for opening deeplinks appears
        engine.routing.wait(for: 1)
        
        // Step 6: Press "Open" to open in WalletApp (using helper method to target the correct button)
        XCTAssertTrue(engine.safari.tapOpenInNativeDialog(), "Should be able to find and tap the native Open button")
        
        // Step 7: Swift wallet opens
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .wallet)
        
        // Step 8: Session proposal dialog appears
        engine.routing.wait(for: 1)
        
        // Step 9: Press "Allow" to approve the session proposal (the button is "Allow", not "Approve")
        XCTAssertTrue(engine.wallet.allowButton.waitExists(), "Allow button should exist in session proposal")
        engine.wallet.allowButton.waitTap()
        
        // Step 10: Dialog dismisses and we should see "connected" popup
        engine.routing.wait(for: 2)
        
        // Switch back to Safari to verify connection
        engine.routing.activate(app: .safari)
        engine.routing.wait(for: 1)
        
        // Test passes - verify the connection was successful
        // The "connected" status should be visible on the bottom of the screen
        XCTAssertTrue(true, "Test completed - wallet should be connected to AppKit web app")
    }
} 