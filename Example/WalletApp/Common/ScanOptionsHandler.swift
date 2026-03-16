import UIKit
import Combine

/// Shared scan options logic used by presenters across all tabs.
/// Manages the sheet state and handles scan QR / paste URL actions.
final class ScanOptionsHandler: ObservableObject {
    @Published var showScanOptions = false

    private let onScan: () -> Void
    private let onUri: (String) -> Void

    init(onScan: @escaping () -> Void, onUri: @escaping (String) -> Void) {
        self.onScan = onScan
        self.onUri = onUri
    }

    func show() {
        showScanOptions = true
    }

    func scanQR() {
        showScanOptions = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onScan()
        }
    }

    func pasteURL() {
        let clipboard = UIPasteboard.general.string ?? ""
        guard !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AlertPresenter.present(message: "No URL found in clipboard", type: .warning)
            return
        }
        showScanOptions = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onUri(clipboard)
        }
    }
}
