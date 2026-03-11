import SwiftUI

protocol SceneViewModel {
    var sceneTitle: String? { get }
    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode { get }
    var leftBarButtonItem: UIBarButtonItem? { get }
    var rightBarButtonItem: UIBarButtonItem? { get }
    var preferredStatusBarStyle: UIStatusBarStyle { get }
    var isNavigationBarTranslucent: Bool { get }
    var isNavigationBarHidden: Bool { get }

}

extension SceneViewModel {
    var sceneTitle: String? {
        return nil
    }
    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .never
    }
    var leftBarButtonItem: UIBarButtonItem? {
        return .none
    }
    var rightBarButtonItem: UIBarButtonItem? {
        return .none
    }
    var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    var isNavigationBarTranslucent: Bool {
        return true
    }
    var isNavigationBarHidden: Bool {
        return false
    }
}

class SceneViewController<ViewModel: SceneViewModel, Content: View>: UIHostingController<Content> {
    private let viewModel: ViewModel

    init(viewModel: ViewModel, content: Content) {
        self.viewModel = viewModel
        super.init(rootView: content)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return viewModel.preferredStatusBarStyle
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(viewModel.isNavigationBarHidden, animated: false)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Privates
private extension SceneViewController {
    func setupView() {
        view.backgroundColor = .w_background
    }

    func setupNavigation() {
        navigationController?.setNavigationBarHidden(viewModel.isNavigationBarHidden, animated: false)
        navigationItem.title = viewModel.sceneTitle
        navigationItem.backButtonTitle = .empty
        navigationItem.largeTitleDisplayMode = viewModel.largeTitleDisplayMode
        navigationItem.rightBarButtonItem = viewModel.rightBarButtonItem
        navigationItem.leftBarButtonItem = viewModel.leftBarButtonItem
    }
}
