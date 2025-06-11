import XCTest

class UITestsWalletAgainstAppKitWeb: XCTestCase {
    private let engine: Engine = Engine()

    override class func setUp() {
        let engine: Engine = Engine()
        // Launch Safari with clean state (this will reset Safari data)
        engine.routing.launch(app: .safari, clean: true)
        engine.routing.launch(app: .wallet, clean: true)
    }

    //Test Case 2.2: Connecting Sample Wallet to AppKit/React App in Mobile Browser and Rejecting Session Proposal
    /// Test connecting Sample Wallet to AppKit/React App in Mobile Browser and rejecting session proposal
    func testConnectWalletToAppKitWebAndRejectSession() {
        // Step 1: Open browser to AppKit URL with clean state
        engine.routing.activate(app: .safari)
        engine.routing.wait(for: 2)
        
        // Navigate to AppKit lab URL
        engine.safari.navigateToAppKit()
        
        // Wait for page to load
        engine.routing.wait(for: 3)
        
        // Check if there's an existing connection and disconnect if needed
        engine.safari.handleDisconnectOrConnect()
        engine.routing.wait(for: 2)
        
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
        
        // Step 9: Press "Decline" to reject the session proposal
        XCTAssertTrue(engine.wallet.rejectButton.waitExists(), "Decline button should exist in session proposal")
        engine.wallet.rejectButton.waitTap()
        
        // Step 10: Dialog dismisses - verify the Allow and Decline buttons no longer exist
        engine.routing.wait(for: 2)
        
        // Verify that the session proposal dialog has disappeared by checking buttons don't exist
        XCTAssertFalse(engine.wallet.allowButton.waitForAppearence(timeout: 1), "Allow button should no longer exist after rejection")
        XCTAssertFalse(engine.wallet.rejectButton.waitForAppearence(timeout: 1), "Reject button should no longer exist after rejection")
        
        // Test passes - session proposal was successfully rejected and dialog dismissed
        XCTAssertTrue(true, "Test completed - session proposal was successfully rejected and dialog dismissed")
    }

    //Test Case 2.1: Connecting Sample Wallet to AppKit/React App in Mobile Browser and Approving Session Proposal
    /// Test connecting Sample Wallet to AppKit/React App in Mobile Browser and approving session proposal
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
        
        // Step 11: Go back to Safari and verify connection
        engine.routing.activate(app: .safari)
        engine.routing.wait(for: 2)
        
        // Verify "connected" status appears
        XCTAssertTrue(engine.safari.connectedStatus.waitExists(), "Connected status should appear on the page")
        
        // Test passes - connection established successfully
        XCTAssertTrue(true, "Test completed - wallet successfully connected to AppKit web app")
    }

    //Test Case 2.3: Accept Sign Message in Sample Wallet
    /// Test signing a message in Sample Wallet via AppKit/React App in Mobile Browser
    func testSignMessageInConnectedWalletViaAppKitWeb() {
        // Step 1: Open browser to AppKit URL with clean state
        engine.routing.activate(app: .safari)
        engine.routing.wait(for: 2)
        
        // Navigate to AppKit lab URL
        engine.safari.navigateToAppKit()
        
        // Wait for page to load
        engine.routing.wait(for: 3)
        
        // Step 2: Scroll down to find "sign message" button (more aggressive scrolling)
        engine.safari.scrollDownToFindSignMessageButton()
        
        // Step 3: Press "sign message" button
        XCTAssertTrue(engine.safari.signMessageButton.waitExists(), "Sign message button should exist on the page")
        engine.safari.signMessageButton.waitTap()
        
        // Step 4: Native popup for deeplink appears
        engine.routing.wait(for: 1)
        
        // Step 5: Press "Open" to open in WalletApp
        XCTAssertTrue(engine.safari.tapOpenInNativeDialog(), "Should be able to find and tap the native Open button for sign message")
        
        // Step 6: Wallet opens
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .wallet)
        
        // Step 7: Press "Allow" button in wallet for sign message request
        engine.routing.wait(for: 1)
        XCTAssertTrue(engine.wallet.allowButton.waitExists(), "Allow button should exist for sign message request")
        engine.wallet.allowButton.waitTap()
        
        // Step 8: A view appears with "request is signed" - that's our test expectation
        engine.routing.wait(for: 2)
        XCTAssertTrue(engine.wallet.requestSignedText.waitExists(), "Request is signed text should appear")
        
        // Test passes - verify the sign message was successful
        XCTAssertTrue(true, "Test completed - sign message request was successful")
    }

    //Test Case 2.4: Reject Sign Message in Sample Wallet
    /// Test rejecting a sign message in Sample Wallet via AppKit/React App in Mobile Browser
    func testRejectSignMessageInConnectedWalletViaAppKitWeb() {
        // Step 1: Open browser to AppKit URL with clean state
        engine.routing.activate(app: .safari)
        engine.routing.wait(for: 2)
        
        // Navigate to AppKit lab URL
        engine.safari.navigateToAppKit()
        
        // Wait for page to load
        engine.routing.wait(for: 3)
        
        // Step 2: Scroll down to find "sign message" button (more aggressive scrolling)
        engine.safari.scrollDownToFindSignMessageButton()
        
        // Step 3: Press "sign message" button
        XCTAssertTrue(engine.safari.signMessageButton.waitExists(), "Sign message button should exist on the page")
        engine.safari.signMessageButton.waitTap()
        
        // Step 4: Native popup for deeplink appears
        engine.routing.wait(for: 1)
        
        // Step 5: Press "Open" to open in WalletApp
        XCTAssertTrue(engine.safari.tapOpenInNativeDialog(), "Should be able to find and tap the native Open button for sign message")
        
        // Step 6: Wallet opens
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .wallet)
        
        // Step 7: Press "Decline" button in wallet to reject sign message request
        engine.routing.wait(for: 1)
        XCTAssertTrue(engine.wallet.sessionRequestDeclineButton.waitExists(), "Decline button should exist for sign message request")
        engine.wallet.sessionRequestDeclineButton.waitTap()
        
        // Step 8: Go back to Safari to check for failure message
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .safari)
        engine.routing.wait(for: 2)
        
        // Step 9: Verify "Signing Failed" status appears
        XCTAssertTrue(engine.safari.signingFailedStatus.waitExists(), "Signing Failed status should appear on the page")
        
        // Test passes - verify the sign message rejection was handled correctly
        XCTAssertTrue(true, "Test completed - sign message request was correctly rejected")
    }
} 
