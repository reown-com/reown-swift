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

    func presentScannerOptions(onScanQR: @escaping () -> Void, onPasteURL: @escaping () -> Void) {
        let vc = ScannerOptionsModule.create(
            app: app,
            onScanQR: onScanQR,
            onPasteURL: onPasteURL,
            onClose: { [weak self] in
                self?.dismissPresented()
            }
        )
        UIApplication.currentWindow.rootViewController?.present(vc, animated: true)
    }

    func presentScan(onValue: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        ScanModule.create(app: app, onValue: onValue, onError: onError)
            .wrapToNavigationController()
            .present(from: viewController)
    }

    func dismiss() {
        viewController.dismiss()
    }

    func dismissPresented() {
        UIApplication.currentWindow.rootViewController?.dismiss(animated: true)
    }

    func dismissToPresent(then completion: @escaping () -> Void) {
        if let presented = UIApplication.currentWindow.rootViewController?.presentedViewController {
            presented.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
    }
}
