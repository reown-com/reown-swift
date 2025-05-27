import Foundation
import XCTest

struct DAppEngine {

    private var instance: XCUIApplication {
        return App.dapp.instance
    }

    // Main screen

    var connectButton: XCUIElement {
        instance.buttons["Connect"]
    }

    var oneClickAuthWithLinkModeButton: XCUIElement {
        instance.buttons["1-Click Auth with Link Mode"]
    }

    // Accounts screen

    var accountRow: XCUIElement {
        instance.staticTexts["0xe5EeF1368781911d265fDB6946613dA61915a501"]
    }

    var firstAccountCell: XCUIElement {
        // This will find the first button that matches the account pattern (starts with eip155:1:0x)
        return instance.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'eip155:1:0x'")).firstMatch
    }

    var disconnectButton: XCUIElement {
        instance.buttons["Disconnect"]
    }

    // SessionAccount screen (after clicking account)

    var personalSignButton: XCUIElement {
        instance.buttons["personal_sign"]
    }

    // Alternative way to find personal_sign if it's in a method list
    var personalSignMethodButton: XCUIElement {
        instance.buttons["method-1"] // personal_sign is usually the second method (index 1)
    }

    // Pairing screen

    var pairingRow: XCUIElement {
        instance.staticTexts["Example Wallet"]
    }

    var newPairingButton: XCUIElement {
        instance.buttons["New Pairing"]
    }

    var copyURIButton: XCUIElement {
        instance.buttons["Copy"]
    }
}
