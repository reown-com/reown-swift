import Foundation
import XCTest

struct SafariEngine {

    private var instance: XCUIApplication {
        return App.safari.instance
    }

    // Navigation elements
    var addressBar: XCUIElement {
        instance.textFields["Address"]
    }
    
    var goButton: XCUIElement {
        instance.buttons["Go"]
    }
    
    // AppKit web interface elements
    var connectWalletButton: XCUIElement {
        instance.buttons["Connect Wallet"]
    }
    
    var swiftSampleWalletButton: XCUIElement {
        instance.buttons["Swift Sample Wallet"]
    }
    
    var signMessageButton: XCUIElement {
        instance.buttons["Sign Message"]
    }
    
    var disconnectButton: XCUIElement {
        instance.buttons["Disconnect"]
    }
    
    // iOS deeplink dialog elements - targeting the specific native dialog
    var openInWalletAppButton: XCUIElement {
        // First try to find the Open button in the SFDialogView (native iOS dialog)
        return instance.otherElements["SFDialogView"].buttons["Open"]
    }
    
    var cancelButton: XCUIElement {
        instance.buttons["Cancel"]
    }
    
    // Alternative selectors for web elements that might appear as links or other elements
    var connectWalletLink: XCUIElement {
        instance.links["Connect Wallet"]
    }
    
    var swiftSampleWalletLink: XCUIElement {
        instance.links["Swift Sample Wallet"]
    }
    
    var signMessageLink: XCUIElement {
        instance.links["Sign Message"]
    }
    
    // Web content elements (if needed)
    var webView: XCUIElement {
        instance.webViews.firstMatch
    }
    
    // Status elements
    var connectedStatus: XCUIElement {
        instance.staticTexts["connected"]
    }
    
    var signingFailedStatus: XCUIElement {
        instance.staticTexts["Signing Failed"]
    }
    
    // Generic web elements (use when specific selectors don't work)
    var anyConnectButton: XCUIElement {
        instance.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'connect'")).firstMatch
    }
    
    var anySwiftWalletButton: XCUIElement {
        instance.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'swift'")).firstMatch
    }
    
    var anySignMessageButton: XCUIElement {
        instance.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sign message'")).firstMatch
    }
    
    // Helper method to navigate to AppKit URL with clean approach
    func navigateToAppKit() {
        // Tap the address bar to focus it
        addressBar.waitTap()
        
        // Wait for the address bar to be ready - wait for it to be focused instead of fixed delay
        if !addressBar.waitForExistence(timeout: 0.5) {
            print("Address bar did not become ready within 0.5 seconds")
        }
        
        // Completely clear the text field by setting it to empty
        // This is more reliable than trying to select and replace
        if let currentValue = addressBar.value as? String, !currentValue.isEmpty {
            // Clear using the XCUIElement clearAndEnterText approach
            addressBar.clearAndEnterText("https://appkit-lab.reown.com/library/wagmi/")
        } else {
            // If empty, just type the URL
            addressBar.typeText("https://appkit-lab.reown.com/library/wagmi/")
        }
        
        goButton.waitTap()
    }
    
    // Helper method to find and tap connect wallet with multiple fallback strategies
    func tapConnectWallet() -> Bool {
        if connectWalletButton.waitForAppearence(timeout: 3) {
            connectWalletButton.waitTap()
            return true
        } else if connectWalletLink.waitForAppearence(timeout: 2) {
            connectWalletLink.waitTap()
            return true
        } else if anyConnectButton.waitForAppearence(timeout: 2) {
            anyConnectButton.waitTap()
            return true
        }
        return false
    }
    
    // Helper method to find and tap Swift wallet with multiple fallback strategies
    func tapSwiftWallet() -> Bool {
        if swiftSampleWalletButton.waitForAppearence(timeout: 3) {
            swiftSampleWalletButton.waitTap()
            return true
        } else if swiftSampleWalletLink.waitForAppearence(timeout: 2) {
            swiftSampleWalletLink.waitTap()
            return true
        } else if anySwiftWalletButton.waitForAppearence(timeout: 2) {
            anySwiftWalletButton.waitTap()
            return true
        }
        return false
    }
    
    // Helper method to tap the correct Open button in the native dialog
    func tapOpenInNativeDialog() -> Bool {
        // Try to find the SFDialogView first
        let dialogView = instance.otherElements["SFDialogView"]
        if dialogView.waitForAppearence(timeout: 3) {
            let openButton = dialogView.buttons["Open"]
            if openButton.waitForAppearence(timeout: 1) {
                openButton.waitTap()
                return true
            }
        }
        
        // Fallback: Try to find any dialog-like container with both Open and Cancel buttons
        let dialogContainers = instance.otherElements.containing(.button, identifier: "Cancel").containing(.button, identifier: "Open")
        if dialogContainers.count > 0 {
            let openButton = dialogContainers.firstMatch.buttons["Open"]
            if openButton.waitForAppearence(timeout: 1) {
                openButton.waitTap()
                return true
            }
        }
        
        return false
    }
    
    // Helper method to scroll down and find sign message button
    func scrollDownToFindSignMessageButton() {
        // First try to find the button without scrolling
        if signMessageButton.waitForAppearence(timeout: 2) || signMessageLink.waitForAppearence(timeout: 1) {
            return
        }
        
        // If not found, scroll down much more aggressively to find it
        let webView = instance.webViews.firstMatch
        if webView.exists {
            print("Starting aggressive scrolling to find Sign Message button")
            
            // Try many more scroll attempts with different techniques
            for i in 0..<15 {
                print("Scrolling attempt \(i + 1) to find sign message button")
                
                // Use different scrolling techniques
                if i < 8 {
                    // Regular swipe up
                    webView.swipeUp()
                } else if i < 12 {
                    // More aggressive swipe with longer drag
                    let startCoord = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                    let endCoord = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                    startCoord.press(forDuration: 0.1, thenDragTo: endCoord)
                } else {
                    // Very aggressive scroll - drag from bottom to very top
                    let startCoord = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
                    let endCoord = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
                    startCoord.press(forDuration: 0.2, thenDragTo: endCoord)
                }
                
                // Wait for content to stabilize after scroll instead of fixed delay
                if !webView.waitForExistence(timeout: 1.5) {
                    print("WebView did not stabilize within 1.5 seconds after scroll")
                }
                
                // Check for the button after each scroll with all possible selectors
                if signMessageButton.waitForAppearence(timeout: 2) || signMessageLink.waitForAppearence(timeout: 1) || anySignMessageButton.waitForAppearence(timeout: 1) {
                    print("Found Sign Message button after \(i + 1) scroll attempts")
                    return
                }
                
                // Every few attempts, do an extra small scroll
                if i % 3 == 2 {
                    webView.swipeUp()
                    // Wait for scroll to complete instead of fixed delay
                    if !webView.waitForExistence(timeout: 0.5) {
                        print("WebView did not stabilize after extra scroll")
                    }
                }
            }
            
            print("Could not find Sign Message button after extensive scrolling")
        }
    }
    
    // Helper method to handle disconnect with scrolling and fallback
    func handleDisconnectOrConnect() -> Bool {
        // First try to find disconnect button without scrolling
        if disconnectButton.waitForAppearence(timeout: 2) {
            // If multiple disconnect buttons exist, try to tap the first one that's visible
            let disconnectButtons = instance.buttons.matching(NSPredicate(format: "label == 'Disconnect'"))
            if disconnectButtons.count > 1 {
                // Try to find the one that's actually visible and tappable
                for i in 0..<disconnectButtons.count {
                    let button = disconnectButtons.element(boundBy: i)
                    if button.isHittable {
                        button.waitTap()
                        return true
                    }
                }
            } else {
                disconnectButton.waitTap()
                return true
            }
        }
        
        // If disconnect not found, scroll down to look for it
        let webView = instance.webViews.firstMatch
        if webView.exists {
            print("Scrolling down to find Disconnect button")
            webView.swipeUp() // Scroll down
            // Wait for scroll to complete and content to stabilize
            if !webView.waitForExistence(timeout: 1.0) {
                print("WebView did not stabilize within 1.0 seconds after scroll")
            }
            
            // Try again after scrolling
            if disconnectButton.waitForAppearence(timeout: 2) {
                let disconnectButtons = instance.buttons.matching(NSPredicate(format: "label == 'Disconnect'"))
                if disconnectButtons.count > 1 {
                    for i in 0..<disconnectButtons.count {
                        let button = disconnectButtons.element(boundBy: i)
                        if button.isHittable {
                            button.waitTap()
                            return true
                        }
                    }
                } else {
                    disconnectButton.waitTap()
                    return true
                }
            }
        }
        
        // If still not found, check if connect button is there (meaning we're already disconnected)
        if connectWalletButton.waitForAppearence(timeout: 2) || connectWalletLink.waitForAppearence(timeout: 1) || anyConnectButton.waitForAppearence(timeout: 1) {
            print("Found connect button - wallet appears to be already disconnected")
            return true
        }
        
        print("Could not find disconnect or connect button")
        return false
    }
}
