import Foundation

enum TabPage: CaseIterable, Hashable {
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

    var systemImage: String {
        switch self {
        case .wallets:
            return "wallet.bifold.fill"
        case .connectedApps:
            return "square.stack.3d.up.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}
