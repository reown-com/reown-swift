import UIKit

final class SettingsRouter {

    weak var viewController: UIViewController!

    private let app: Application

    init(app: Application) {
        self.app = app
    }

    @MainActor func presentWelcome() async {
        WelcomeModule.create(app: app).present()
    }

    func presentBrowser() {
        BrowserModule.create(app: app)
            .push(from: viewController)
    }

    func presentScan(onValue: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        ScanModule.create(app: app, onValue: onValue, onError: onError)
            .wrapToNavigationController()
            .present(from: viewController)
    }

    func presentPaste(onValue: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        PasteUriModule.create(app: app, onValue: onValue, onError: onError)
            .presentFullScreen(from: viewController, transparentBackground: true)
    }

    func dismiss() {
        viewController.dismiss()
    }
}
