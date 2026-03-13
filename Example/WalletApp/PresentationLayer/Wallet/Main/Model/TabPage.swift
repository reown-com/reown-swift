import UIKit

enum TabPage: CaseIterable {
    case wallets
    case connectedApps
    case settings

    var title: String {
        switch self {
        case .wallets:
            return "Wallets"
        case .connectedApps:
            return "Connected Apps"
        case .settings:
            return "Settings"
        }
    }

    var icon: UIImage {
        switch self {
        case .wallets:
            return UIImage(systemName: "wallet.bifold.fill")
                ?? UIImage(systemName: "creditcard.fill")!
        case .connectedApps:
            return UIImage(systemName: "square.stack.3d.up.fill")
                ?? UIImage(named: "connections_tab")!
        case .settings:
            return UIImage(systemName: "gearshape.fill")
                ?? UIImage(named: "settings_tab")!
        }
    }

    static var selectedIndex: Int {
        return 0
    }

    static var enabledTabs: [TabPage] {
        return [.wallets, .connectedApps, .settings]
    }
}
