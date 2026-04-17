import UIKit
import Combine

/// Shared scan options logic used by presenters across all tabs.
/// Manages the sheet state and handles scan QR / paste URL actions.
final class ScanOptionsHandler: ObservableObject {
    @Published var showScanOptions = false
    @Published var testModeUrl: String = ""

    /// Override for scan camera presentation (set by coordinator)
    var onScanOverride: (() -> Void)?

    private let onScan: () -> Void
    private let onUri: (String) -> Void

    var isTestMode: Bool {
        #if ENABLE_TEST_MODE
        return true
        #else
        return false
        #endif
    }

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
            if let override = self?.onScanOverride {
                override()
            } else {
                self?.onScan()
            }
        }
    }

    func pasteURL() {
        let clipboard = UIPasteboard.general.string ?? ""
        guard !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            WalletToast.present(message: "No URL found in clipboard", type: .warning)
            return
        }
        showScanOptions = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onUri(clipboard)
        }
    }

    func submitTestUrl() {
        let url = testModeUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        showScanOptions = false
        testModeUrl = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onUri(url)
        }
    }
}
