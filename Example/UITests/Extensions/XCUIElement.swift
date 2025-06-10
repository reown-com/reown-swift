import Foundation
import XCTest

extension XCUIElement {

    @discardableResult
    func waitForAppearence(timeout: TimeInterval = 5) -> Bool {
        return waitForExistence(timeout: timeout)
    }

    func waitTap() {
        waitForAppearence()
        tap()
    }

    func waitTypeText(_ text: String) {
        waitForAppearence()
        typeText(text)
    }

    func waitExists() -> Bool {
        waitForAppearence()
        return exists
    }
    
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non-string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}
