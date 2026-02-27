import AppIntents
import SwiftUI
import WidgetKit

// MARK: - App Intent

@available(iOS 18.0, *)
struct TapToPayIntent: AppIntent {
    static var title: LocalizedStringResource = "Tap to Pay"
    static var description: IntentDescription = "Open wallet NFC reader"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Signal the app to start NFC scan on activation.
        // openAppWhenRun opens the app; we write a flag so SceneDelegate
        // knows to trigger the NFC reader.
        let defaults = UserDefaults(suiteName: "group.com.walletconnect.sdk")
        defaults?.set(true, forKey: "pendingNfcPay")
        return .result()
    }
}

// MARK: - Control Center Widget

@available(iOS 18.0, *)
struct TapToPayControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "TapToPayControl") {
            ControlWidgetButton(action: TapToPayIntent()) {
                Label("Tap to Pay", systemImage: "wave.3.right")
            }
        }
        .displayName("Tap to Pay")
        .description("Open wallet NFC reader")
    }
}
