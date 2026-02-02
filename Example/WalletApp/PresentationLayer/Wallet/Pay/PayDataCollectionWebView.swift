import SwiftUI
import WebKit

struct PayDataCollectionWebView: UIViewRepresentable {
    let url: URL
    let onComplete: () -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Register message handler matching the IC page's expected name
        config.userContentController.add(context.coordinator, name: "payDataCollectionComplete")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white

        print("💳 [PayWebView] Loading URL: \(url)")
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        let onComplete: () -> Void
        let onError: (String) -> Void

        init(onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
            self.onComplete = onComplete
            self.onError = onError
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
                print("💳 [PayWebView] IC_COMPLETE received, success: \(success)")
                if success {
                    DispatchQueue.main.async { [weak self] in
                        self?.onComplete()
                    }
                }
            case "IC_ERROR":
                let error = body["error"] as? String ?? "Unknown error"
                print("💳 [PayWebView] IC_ERROR received: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.onError(error)
                }
            default:
                print("💳 [PayWebView] Unknown message type: \(type)")
                DispatchQueue.main.async { [weak self] in
                    self?.onError("Unknown message type: \(type)")
                }
            }
        }

        // Capture console.log from JavaScript
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("💳 [PayWebView] JS Alert: \(message)")
            completionHandler()
        }

        // Handle navigation errors
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("💳 [PayWebView] Navigation failed: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.onError("Navigation failed: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("💳 [PayWebView] Failed to load: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.onError("Failed to load page: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("💳 [PayWebView] Page loaded successfully")
        }
    }
}

#if DEBUG
struct PayDataCollectionWebView_Previews: PreviewProvider {
    static var previews: some View {
        PayDataCollectionWebView(
            url: URL(string: "https://example.com")!,
            onComplete: {},
            onError: { _ in }
        )
    }
}
#endif
