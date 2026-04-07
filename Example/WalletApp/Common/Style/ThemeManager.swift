import SwiftUI
import UIKit

final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    private static let storageKey = "dark_mode"

    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: Self.storageKey)
            applyToWindows()
        }
    }

    private init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: Self.storageKey)
    }

    /// Call on app launch to apply the persisted theme preference.
    func apply() {
        applyToWindows()
    }

    private func applyToWindows() {
        let style: UIUserInterfaceStyle = isDarkMode ? .dark : .light
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}
