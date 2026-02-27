import WidgetKit
import SwiftUI

@main
struct TapToPayWidgetBundle: WidgetBundle {
    var body: some Widget {
        TapToPayWidget()
        // TapToPayControlWidget is iOS 18+ only.
        // WidgetBundleBuilder doesn't support runtime #available checks.
        // On iOS 18+ devices the Control Center widget is registered
        // automatically via ControlWidgetEligibility in the extension's
        // Info.plist when the type conforms to ControlWidget.
    }
}
