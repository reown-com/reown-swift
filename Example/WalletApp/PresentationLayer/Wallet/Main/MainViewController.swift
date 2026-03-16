import UIKit

final class MainViewController: UITabBarController {

    private let presenter: MainPresenter

    init(presenter: MainPresenter) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        styleTabBar()
        setupTabs()
    }

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .appBackgroundPrimary
        appearance.shadowColor = .clear

        // Normal state
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "KHTeka-Regular", size: 10) ?? .systemFont(ofSize: 10),
            .foregroundColor: UIColor.appTextSecondary
        ]

        // Selected state
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "KHTeka-Medium", size: 10) ?? .systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.appAccentPrimary
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.stackedLayoutAppearance.normal.iconColor = .appTextSecondary
        appearance.stackedLayoutAppearance.selected.iconColor = .appAccentPrimary

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        // Add top border (skip on iOS 26+ where liquid glass provides its own treatment)
        if #unavailable(iOS 26) {
            let border = UIView()
            border.backgroundColor = .appBorderPrimary
            border.translatesAutoresizingMaskIntoConstraints = false
            tabBar.addSubview(border)
            NSLayoutConstraint.activate([
                border.topAnchor.constraint(equalTo: tabBar.topAnchor),
                border.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
                border.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
                border.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
    }

    private func setupTabs() {
        let viewControllers = presenter.viewControllers

        for (index, viewController) in viewControllers.enumerated() {
            let model = presenter.tabs[index]
            let item = UITabBarItem()
            item.title = model.title
            item.image = model.icon
            item.isEnabled = TabPage.enabledTabs.contains(model)
            viewController.tabBarItem = item
            viewController.view.backgroundColor = .appBackgroundPrimary
        }

        self.viewControllers = viewControllers
        self.selectedIndex = TabPage.selectedIndex
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
