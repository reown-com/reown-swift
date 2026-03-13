import SwiftUI

final class ScannerOptionsModule {
    @discardableResult
    static func create(
        app: Application,
        onScanQR: @escaping () -> Void,
        onPasteURL: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) -> UIViewController {
        let view = ScannerOptionsView(
            onScanQR: onScanQR,
            onPasteURL: onPasteURL,
            onClose: onClose
        )
        let viewController = UIHostingController(rootView: view)
        viewController.modalPresentationStyle = .overFullScreen
        viewController.modalTransitionStyle = .crossDissolve
        viewController.view.backgroundColor = .clear
        return viewController
    }
}
