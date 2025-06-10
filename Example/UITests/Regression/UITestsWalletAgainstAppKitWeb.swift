import XCTest

class UITestsWalletAgainstAppKitWeb: XCTestCase {
    private let engine: Engine = Engine()

    override class func setUp() {
        let engine: Engine = Engine()
        // Launch Safari with clean state (this will reset Safari data)
        engine.routing.launch(app: .safari, clean: true)
        engine.routing.launch(app: .wallet, clean: true)
    }

    //Test Case 2.1: Connecting Sample Wallet to AppKit/React App in Mobile Browser and Approving Session Proposal
    //Test Case 2.3: Accept Sign Message in Sample Wallet
    /// Test connecting Sample Wallet to AppKit/React App in Mobile Browser, approving session proposal, and accepting sign message
    /// - TU009
    func testConnectWalletToAppKitWebAndApproveSession() {
        // Step 1: Open browser to AppKit URL with clean state
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
        
        // Step 10: Dialog dismisses and connection is established
        engine.routing.wait(for: 2)
        
        // Step 11: Go back to Safari
        engine.routing.activate(app: .safari)
        engine.routing.wait(for: 1)
        
        // Step 12: Scroll down to find "sign message" button
        engine.safari.scrollDownToFindSignMessageButton()
        
        // Step 13: Press "sign message" button
        XCTAssertTrue(engine.safari.signMessageButton.waitExists(), "Sign message button should exist on the page")
        engine.safari.signMessageButton.waitTap()
        
        // Step 14: Native popup for deeplink appears again
        engine.routing.wait(for: 1)
        
        // Step 15: Press "Open" to open in WalletApp
        XCTAssertTrue(engine.safari.tapOpenInNativeDialog(), "Should be able to find and tap the native Open button for sign message")
        
        // Step 16: Wallet opens
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .wallet)
        
        // Step 17: Press "Allow" button in wallet for sign message request
        engine.routing.wait(for: 1)
        XCTAssertTrue(engine.wallet.allowButton.waitExists(), "Allow button should exist for sign message request")
        engine.wallet.allowButton.waitTap()
        
        // Step 18: A view appears with "request is signed" - that's our test expectation
        engine.routing.wait(for: 2)
        XCTAssertTrue(engine.wallet.requestSignedText.waitExists(), "Request is signed text should appear")
        
        // Test passes - verify the sign message was successful
        XCTAssertTrue(true, "Test completed - wallet connected to AppKit web app and sign message request was successful")
    }
} 