import UIKit

struct AppearanceConfigurator: Configurator {

    func configure() {
        ThemeManager.shared.apply()
    }
}
