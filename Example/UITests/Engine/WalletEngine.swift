import Foundation
import XCTest

struct WalletEngine {

    private var instance: XCUIApplication {
        return App.wallet.instance
    }

    // MainScreen

    var pasteURIButton: XCUIElement {
        instance.buttons["Paste URI"]
    }

    var alert: XCUIElement {
        instance.alerts["Paste URI"]
    }

    var uriTextfield: XCUIElement {
        alert.textFields.firstMatch
    }

    var pasteAndConnect: XCUIElement {
        alert.buttons["Paste and Connect"]
    }

    var sessionRow: XCUIElement {
        instance.staticTexts["Swift Dapp"]
    }

    // AuthRequest (Session Authentication) buttons

    var approveButton: XCUIElement {
        instance.buttons["Approve"]
    }

    var rejectButton: XCUIElement {
        instance.buttons["Reject"]
    }

    var signOneButton: XCUIElement {
        instance.buttons["Sign One"]
    }

    var declineButton: XCUIElement {
        instance.buttons["Decline"]
    }

    // SessionRequest (personal_sign, etc.) buttons
    
    var allowButton: XCUIElement {
        instance.buttons["Allow"]
    }

    var sessionRequestDeclineButton: XCUIElement {
        instance.buttons["Decline"]
    }

    // SessionDetails

    var pingButton: XCUIElement {
        instance.buttons["Ping"]
    }

    var okButton: XCUIElement {
        instance.buttons["OK"]
    }

    var pingAlert: XCUIElement {
        instance.alerts.element.staticTexts["Received ping response"]
    }

    // Sign message completion elements
    var requestSignedText: XCUIElement {
        instance.staticTexts["Request is signed"]
    }

    // Alternative ways to detect successful sign message
    var requestSignedLabel: XCUIElement {
        instance.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'signed'")).firstMatch
    }

    func swipeDismiss() {
        instance.swipeDown(velocity: .fast)
    }
}
