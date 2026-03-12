import SwiftUI
import WebKit

struct PayDataCollectionWebView: View {
    let url: URL
    let onClose: () -> Void
    let onComplete: () -> Void
    let onError: (String) -> Void
    let onFormDataChanged: (_ fullName: String?, _ dob: String?, _ pobAddress: String?) -> Void

    @State private var isLoading = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PayWebViewRepresentable(
                url: url,
                isLoading: $isLoading,
                onComplete: onComplete,
                onError: onError,
                onFormDataChanged: onFormDataChanged
            )

            // Close button — matches other Pay modals
            PayCloseButton(action: onClose)
                .padding(.top, Spacing._4)
                .padding(.trailing, Spacing._5)

            if isLoading {
                VStack {
                    WalletConnectLoadingView(size: 120)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundPrimary)
            }
        }
    }
}

private struct PayWebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    let onComplete: () -> Void
    let onError: (String) -> Void
    let onFormDataChanged: (_ fullName: String?, _ dob: String?, _ pobAddress: String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, onComplete: onComplete, onError: onError, onFormDataChanged: onFormDataChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Register message handler matching the IC page's expected name
        config.userContentController.add(context.coordinator, name: "payDataCollectionComplete")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = UIColor(AppColors.backgroundPrimary)
        webView.scrollView.backgroundColor = UIColor(AppColors.backgroundPrimary)
        webView.isOpaque = false

        print("💳 [PayWebView] Loading URL: \(url)")
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        @Binding var isLoading: Bool
        let onComplete: () -> Void
        let onError: (String) -> Void
        let onFormDataChanged: (_ fullName: String?, _ dob: String?, _ pobAddress: String?) -> Void

        init(isLoading: Binding<Bool>, onComplete: @escaping () -> Void, onError: @escaping (String) -> Void, onFormDataChanged: @escaping (_ fullName: String?, _ dob: String?, _ pobAddress: String?) -> Void) {
            self._isLoading = isLoading
            self.onComplete = onComplete
            self.onError = onError
            self.onFormDataChanged = onFormDataChanged
        }

        // JavaScript calls: window.webkit.messageHandlers.payDataCollectionComplete.postMessage({...})
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            print("💳 [PayWebView] Received message: \(message.body)")

            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                print("💳 [PayWebView] Invalid message format: \(message.body)")
                onError("Invalid message format")
                return
            }

            print("💳 [PayWebView] Message type: \(type)")

            switch type {
            case "IC_COMPLETE":
                let success = body["success"] as? Bool ?? false
                // Extract form data from completion message (same fields as prefill)
                let fullName = body["fullName"] as? String
                let dob = body["dob"] as? String
                let pobAddress = body["pobAddress"] as? String
                print("💳 [PayWebView] IC_COMPLETE received, success: \(success), fullName: \(fullName ?? "nil"), dob: \(dob ?? "nil"), pobAddress: \(pobAddress ?? "nil")")
                if success {
                    DispatchQueue.main.async { [weak self] in
                        self?.onFormDataChanged(fullName, dob, pobAddress)
                        self?.onComplete()
                    }
                }
            case "IC_ERROR":
                let error = body["error"] as? String ?? "Unknown error"
                print("💳 [PayWebView] IC_ERROR received: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.onError(error)
                }
            case "IC_FORM_DATA":
                let fullName = body["fullName"] as? String
                let dob = body["dob"] as? String
                let pobAddress = body["pobAddress"] as? String
                print("💳 [PayWebView] IC_FORM_DATA received - fullName: \(fullName ?? "nil"), dob: \(dob ?? "nil"), pobAddress: \(pobAddress ?? "nil")")
                DispatchQueue.main.async { [weak self] in
                    self?.onFormDataChanged(fullName, dob, pobAddress)
                }
            default:
                // Ignore unknown message types silently (don't treat as error)
                print("💳 [PayWebView] Unknown message type: \(type)")
            }
        }

        // Capture console.log from JavaScript
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("💳 [PayWebView] JS Alert: \(message)")
            completionHandler()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = true
            }
        }

        // Handle navigation errors
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("💳 [PayWebView] Navigation failed: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
                self?.onError("Navigation failed: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("💳 [PayWebView] Failed to load: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
                self?.onError("Failed to load page: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("💳 [PayWebView] Page loaded successfully")
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
        }

        // Handle link clicks - open external links in Safari
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Allow initial page load and same-origin navigations
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
                return
            }

            // For link clicks, open in Safari
            if navigationAction.navigationType == .linkActivated {
                print("💳 [PayWebView] Opening external link in Safari: \(url)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}

#if DEBUG
struct PayDataCollectionWebView_Previews: PreviewProvider {
    static var previews: some View {
        PayDataCollectionWebView(
            url: URL(string: "https://example.com")!,
            onClose: {},
            onComplete: {},
            onError: { _ in },
            onFormDataChanged: { _, _, _ in }
        )
    }
}
#endif
