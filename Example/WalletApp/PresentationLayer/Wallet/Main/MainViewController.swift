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

        // Background color adapts to light/dark
        appearance.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1) // #202020
                : UIColor.white
        }

        // Remove default separator
        appearance.shadowColor = .clear

        // Normal state
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "KHTeka-Regular", size: 10) ?? .systemFont(ofSize: 10),
            .foregroundColor: UIColor(red: 0.604, green: 0.604, blue: 0.604, alpha: 1) // #9A9A9A
        ]

        // Selected state
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "KHTeka-Medium", size: 10) ?? .systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(red: 0.035, green: 0.533, blue: 0.941, alpha: 1) // #0988F0
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(red: 0.604, green: 0.604, blue: 0.604, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.035, green: 0.533, blue: 0.941, alpha: 1)

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        // Add top border
        let border = UIView()
        border.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.212, green: 0.212, blue: 0.212, alpha: 1) // #363636
                : UIColor(red: 0.914, green: 0.914, blue: 0.914, alpha: 1) // #E9E9E9
        }
        border.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(border)
        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: tabBar.topAnchor),
            border.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1)
        ])
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
            viewController.view.backgroundColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1)
                    : UIColor.white
            }
        }

        self.viewControllers = viewControllers
        self.selectedIndex = TabPage.selectedIndex
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
