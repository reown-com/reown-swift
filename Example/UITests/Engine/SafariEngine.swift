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
        instance.buttons["Swift sample wallet"]
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
        instance.links["Swift sample wallet"]
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
    
    // Helper method to navigate to AppKit URL
    func navigateToAppKit() {
        addressBar.waitTap()
        addressBar.typeText("https://appkit-lab.reown.com/library/wagmi/")
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
}
