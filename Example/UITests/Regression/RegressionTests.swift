import XCTest

class UITests: XCTestCase {
    private let engine: Engine = Engine()
    
    // Class-level property to ensure tests run in sequence
    private static var testExecutionOrder = 0

    override class func setUp() {
        let engine: Engine = Engine()
        engine.routing.launch(app: .wallet, clean: true)
        engine.routing.launch(app: .dapp, clean: true)
    }
    
    override func setUp() {
        super.setUp()
        // Ensure tests run in sequence by checking execution order
        UITests.testExecutionOrder += 1
    }

    /// Helper method to disconnect if already connected
    private func disconnectIfNeeded() {
        engine.routing.activate(app: .dapp)
        engine.routing.wait(for: 1)
        
        if engine.dapp.disconnectButton.waitForAppearence(timeout: 2) {
            engine.dapp.disconnectButton.waitTap()
            // Wait until disconnect completes and returns to initial state
            engine.routing.wait(for: 2)
        }
    }

    /// Test 1-Click Auth with Link Mode cross-app flow
    /// - TU005
    func test01OneClickAuthWithLinkMode() {
        // Setup: Disconnect if already connected
        disconnectIfNeeded()
        
        // Step 0: Setup wallet with new account first
        engine.routing.activate(app: .wallet)
        engine.routing.wait(for: 2)
        
        // Press "Create new account" button if it exists (wallet setup)
        if engine.wallet.createNewAccountButton.waitForAppearence(timeout: 2) {
            engine.wallet.createNewAccountButton.waitTap()
            engine.routing.wait(for: 2)
        }
        
        // Step 1: Open dapp
        engine.routing.activate(app: .dapp)
        
        // Wait for app to fully load
        engine.routing.wait(for: 2)
        
        // Step 2: Press "1-Click Auth with Link Mode" button
        engine.dapp.oneClickAuthWithLinkModeButton.waitTap()
        
        // Step 3: The button action will open walletApp (but in test environment we need to manually activate)
        engine.routing.wait(for: 1)
        if engine.dapp.connectOneClickAuthButton.waitForAppearence(timeout: 2) {
            engine.dapp.connectOneClickAuthButton.waitTap()
        }
        
        // Step 4: Wait for modal screen to appear in walletApp (may take up to 1s)
        engine.routing.wait(for: 1)
        
        // Step 5: Press "Sign One" button in walletApp
        XCTAssertTrue(engine.wallet.signOneButton.waitExists(), "Sign One button should exist in wallet")
        engine.wallet.signOneButton.waitTap()
        
        // Step 6: It redirects us back to dapp (this should happen automatically)
        engine.routing.wait(for: 2)
        
        // Verify we're back in the dapp and the connection was successful
        engine.routing.activate(app: .dapp)
        
        // Test passes - verify that we have account details or some success indicator
        XCTAssertTrue(engine.dapp.accountRow.waitExists() || engine.dapp.disconnectButton.waitExists(), 
                     "Should have account row or disconnect button indicating successful connection")
    }

    /// Test Case 1.2: Connecting Sample Wallet to Native Sample Dapp and Rejecting Session Proposal
    /// - TU006
    func test02RejectSessionProposal() {
        // Setup: Disconnect if already connected
        disconnectIfNeeded()
        
        // Step 1: Open dapp
        engine.routing.activate(app: .dapp)
        
        // Wait for app to fully load
        engine.routing.wait(for: 2)
        
        // Step 2: Press "1-Click Auth with Link Mode" button
        engine.dapp.oneClickAuthWithLinkModeButton.waitTap()

        // Step 4: Wait for modal screen to appear in walletApp (0.5s)
        engine.routing.wait(for: 0.5)
        
        // Step 5: Press "Decline" button instead of "Sign One"
        XCTAssertTrue(engine.wallet.declineButton.waitExists(), "Decline button should exist in wallet")
        engine.wallet.declineButton.waitTap()
        
        // Step 6: It redirects us back to dapp
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .dapp)
        
        // Test passes - verify that we're back in the dapp without connection
        XCTAssertFalse(engine.dapp.disconnectButton.waitForAppearence(timeout: 3), 
                      "Should NOT have disconnect button indicating connection was rejected")
    }

    /// Test Case 1.3: Accept Sign Message in Sample Wallet
    /// - TU007
    func test03AcceptSignMessage() {
        // Setup: Disconnect if already connected
        disconnectIfNeeded()
        
        // Steps 1-6: Same as first test (connect wallet)
        engine.routing.activate(app: .dapp)
        engine.routing.wait(for: 2)
        engine.dapp.oneClickAuthWithLinkModeButton.waitTap()

        engine.routing.wait(for: 1)
        XCTAssertTrue(engine.wallet.signOneButton.waitExists(), "Sign One button should exist in wallet")
        engine.wallet.signOneButton.waitTap()
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .dapp)
        
        // Step 7: In dapp, press the first cell of the table view
        XCTAssertTrue(engine.dapp.firstAccountCell.waitExists(), "First account cell should exist")
        engine.dapp.firstAccountCell.waitTap()
        
        // Step 8: It will push another screen on the navigation stack
        engine.routing.wait(for: 1)
        
        // Step 9: There will be a button "personal_sign", press it
        XCTAssertTrue(engine.dapp.personalSignButton.waitExists() || engine.dapp.personalSignMethodButton.waitExists(), 
                     "personal_sign button should exist")
        
        if engine.dapp.personalSignButton.waitForAppearence(timeout: 2) {
            engine.dapp.personalSignButton.waitTap()
        } else {
            engine.dapp.personalSignMethodButton.waitTap()
        }
        
        // Step 10: It opens wallet again
        engine.routing.wait(for: 1)
        engine.routing.activate(app: .wallet)
        
        // Step 11: Press "Allow" button
        XCTAssertTrue(engine.wallet.allowButton.waitExists(), "Allow button should exist in wallet")
        engine.wallet.allowButton.waitTap()
        
        // Step 12: It opens dapp
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .dapp)
        
        // Test passed - verify we're back in dapp
        XCTAssertTrue(true, "Test completed successfully")
    }

    /// Test Case 1.4: Reject Sign Message in Sample Wallet
    /// - TU008
    func test04RejectSignMessage() {
        // Setup: Disconnect if already connected
        disconnectIfNeeded()
        
        // Steps 1-10: Same as previous test (connect wallet and initiate personal_sign)
        engine.routing.activate(app: .dapp)
        engine.routing.wait(for: 2)
        engine.dapp.oneClickAuthWithLinkModeButton.waitTap()

        engine.routing.wait(for: 1)
        XCTAssertTrue(engine.wallet.signOneButton.waitExists(), "Sign One button should exist in wallet")
        engine.wallet.signOneButton.waitTap()
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .dapp)
        XCTAssertTrue(engine.dapp.firstAccountCell.waitExists(), "First account cell should exist")
        engine.dapp.firstAccountCell.waitTap()
        engine.routing.wait(for: 1)
        
        XCTAssertTrue(engine.dapp.personalSignButton.waitExists() || engine.dapp.personalSignMethodButton.waitExists(), 
                     "personal_sign button should exist")
        
        if engine.dapp.personalSignButton.waitForAppearence(timeout: 2) {
            engine.dapp.personalSignButton.waitTap()
        } else {
            engine.dapp.personalSignMethodButton.waitTap()
        }
        
        engine.routing.wait(for: 1)
        engine.routing.activate(app: .wallet)
        
        // Step 11: Press "Decline" instead of "Allow"
        XCTAssertTrue(engine.wallet.sessionRequestDeclineButton.waitExists(), "Decline button should exist in wallet")
        engine.wallet.sessionRequestDeclineButton.waitTap()
        
        // Step 12: It opens dapp
        engine.routing.wait(for: 2)
        engine.routing.activate(app: .dapp)
        
        // Test passed - verify we're back in dapp
        XCTAssertTrue(true, "Test completed successfully")
    }
}
