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
        config.userContentController.add(context.coordinator, name: "iOSWallet")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onComplete: () -> Void
        let onError: (String) -> Void

        init(onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
            self.onComplete = onComplete
            self.onError = onError
        }

        // JavaScript calls: window.webkit.messageHandlers.iOSWallet.postMessage({...})
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                onError("Invalid message format")
                return
            }

            switch type {
            case "IC_COMPLETE":
                if body["success"] as? Bool == true {
                    DispatchQueue.main.async { [weak self] in
                        self?.onComplete()
                    }
                }
            case "IC_ERROR":
                let error = body["error"] as? String ?? "Unknown error"
                DispatchQueue.main.async { [weak self] in
                    self?.onError(error)
                }
            default:
                DispatchQueue.main.async { [weak self] in
                    self?.onError("Unknown message type: \(type)")
                }
            }
        }

        // Handle navigation errors
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in
                self?.onError("Navigation failed: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in
                self?.onError("Failed to load page: \(error.localizedDescription)")
            }
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
