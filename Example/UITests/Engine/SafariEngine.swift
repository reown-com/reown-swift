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
        instance.buttons["sign message"]
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
        instance.links["sign message"]
    }
    
    // Web content elements (if needed)
    var webView: XCUIElement {
        instance.webViews.firstMatch
    }
    
    // Status elements
    var connectedStatus: XCUIElement {
        instance.staticTexts["connected"]
    }
    
    // Generic web elements (use when specific selectors don't work)
    var anyConnectButton: XCUIElement {
        instance.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'connect'")).firstMatch
    }
    
    var anySwiftWalletButton: XCUIElement {
        instance.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'swift'")).firstMatch
    }
    
    var anySignMessageButton: XCUIElement {
        instance.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sign'")).firstMatch
    }
    
    // Helper method to navigate to AppKit URL with clean approach
    func navigateToAppKit() {
        // Tap the address bar to focus it
        addressBar.waitTap()
        
        // Wait for the address bar to be ready
        Thread.sleep(forTimeInterval: 0.5)
        
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
        
        // If not found, scroll down more extensively to find it
        let webView = instance.webViews.firstMatch
        if webView.exists {
            // Try scrolling more times with longer waits
            for i in 0..<8 {
                print("Scrolling attempt \(i + 1) to find sign message button")
                webView.swipeUp() // Scroll down
                
                // Wait longer for content to load after each scroll
                Thread.sleep(forTimeInterval: 1.0)
                
                // Check for the button after each scroll
                if signMessageButton.waitForAppearence(timeout: 2) || signMessageLink.waitForAppearence(timeout: 1) || anySignMessageButton.waitForAppearence(timeout: 1) {
                    print("Found sign message button after \(i + 1) scroll attempts")
                    return
                }
                
                // Also try smaller scrolls occasionally
                if i % 2 == 1 {
                    webView.swipeUp()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            
            // If still not found, try one more aggressive scroll to bottom
            print("Trying final scroll to bottom of page")
            let coordinate = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            let bottomCoordinate = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            coordinate.press(forDuration: 0.1, thenDragTo: bottomCoordinate)
            Thread.sleep(forTimeInterval: 2.0)
        }
    }
}
