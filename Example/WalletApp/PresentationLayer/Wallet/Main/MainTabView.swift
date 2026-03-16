import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            balancesTab
            connectedAppsTab
            settingsTab
        }
        .onAppear {
            configureTabBarAppearance()
        }
    }

    // MARK: - Tabs

    private var balancesTab: some View {
        BalancesView()
            .environmentObject(coordinator.balancesViewModel)
            .tabItem {
                Label(TabPage.wallets.title, systemImage: TabPage.wallets.systemImage)
            }
            .tag(TabPage.wallets)
    }

    private var connectedAppsTab: some View {
        NavigationStack(path: $coordinator.walletPath) {
            WalletView()
                .environmentObject(coordinator.walletPresenter)
                .navigationDestination(for: WalletDestination.self) { destination in
                    switch destination {
                    case .connectionDetails(let session):
                        let presenter = ConnectionDetailsPresenter(session: session)
                        let _ = { presenter.dismissAction = { [weak coordinator] in coordinator?.walletPath.removeLast() } }()
                        ConnectionDetailsView()
                            .environmentObject(presenter)
                    }
                }
        }
        .tabItem {
            Label(TabPage.connectedApps.title, systemImage: TabPage.connectedApps.systemImage)
        }
        .tag(TabPage.connectedApps)
    }

    private var settingsTab: some View {
        NavigationStack(path: $coordinator.settingsPath) {
            SettingsView()
                .environmentObject(coordinator.settingsPresenter)
                .navigationDestination(for: SettingsDestination.self) { destination in
                    switch destination {
                    case .secretPhrase:
                        SecretPhraseView()
                            .environmentObject(
                                SecretPhrasePresenter(accountStorage: coordinator.app.accountStorage)
                            )
                    case .browser:
                        BrowserView()
                            .environmentObject(BrowserPresenter())
                    }
                }
        }
        .tabItem {
            Label(TabPage.settings.title, systemImage: TabPage.settings.systemImage)
        }
        .tag(TabPage.settings)
    }

    // MARK: - Tab Bar Styling

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .appBackgroundPrimary
        appearance.shadowColor = .clear

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "KHTeka-Regular", size: 10) ?? .systemFont(ofSize: 10),
            .foregroundColor: UIColor.appTextSecondary
        ]

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "KHTeka-Medium", size: 10) ?? .systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.appAccentPrimary
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.stackedLayoutAppearance.normal.iconColor = .appTextSecondary
        appearance.stackedLayoutAppearance.selected.iconColor = .appAccentPrimary

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
