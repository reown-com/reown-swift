import SwiftUI
import WebKit

/// Embeds the WalletConnect Pay hosted checkout in a `WKWebView`.
///
/// Mirrors the React Native reference (`react-native-examples` PR #570/#576):
/// - Intercepts wallet deeplinks (`?uri=wc:…`) and forwards them to the OS.
/// - Listens for `PAY_SUCCESS` / `PAY_FAILURE` bridge messages.
///
/// IMPORTANT: the checkout calls `window.ReactNativeWebView.postMessage(...)`, which does NOT
/// exist on a native `WKWebView`. Registering a `WKScriptMessageHandler` named `ReactNativeWebView`
/// only creates `window.webkit.messageHandlers.ReactNativeWebView.postMessage`. We therefore inject
/// a `WKUserScript` shim at document start that maps `window.ReactNativeWebView.postMessage` onto the
/// native handler. Without this shim the success/failure messages are silently dropped.
struct PayWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onSuccess: (String?) -> Void
    var onFailure: (String?) -> Void

    private static let bridgeName = "ReactNativeWebView"

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, onSuccess: onSuccess, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()

        // Shim: expose window.ReactNativeWebView.postMessage backed by the native message handler.
        let shim = """
        window.ReactNativeWebView = {
            postMessage: function (data) {
                window.webkit.messageHandlers.\(Self.bridgeName).postMessage(data);
            }
        };
        """
        contentController.addUserScript(
            WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        contentController.add(context.coordinator, name: Self.bridgeName)

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        // JavaScript and DOM storage are enabled by default on WKWebView; the checkout requires both.

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        @Binding var isLoading: Bool
        let onSuccess: (String?) -> Void
        let onFailure: (String?) -> Void

        init(isLoading: Binding<Bool>, onSuccess: @escaping (String?) -> Void, onFailure: @escaping (String?) -> Void) {
            self._isLoading = isLoading
            self.onSuccess = onSuccess
            self.onFailure = onFailure
        }

        // MARK: Bridge messages

        // The checkout posts a JSON *string* (React Native semantics), so parse the string body.
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == PayWebView.bridgeName else { return }

            guard let body = message.body as? String else {
                print("💳 [PayWebView] Bridge message body is not a string: \(message.body)")
                return
            }
            guard let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("💳 [PayWebView] Failed to parse bridge message JSON: \(body)")
                return
            }

            let type = json["type"] as? String
            let success = json["success"] as? Bool

            if type == "PAY_SUCCESS" || success == true {
                let confirmation = json["message"] as? String
                DispatchQueue.main.async { [weak self] in self?.onSuccess(confirmation) }
            } else if type == "PAY_FAILURE" || success == false {
                let reason = json["error"] as? String
                DispatchQueue.main.async { [weak self] in self?.onFailure(reason) }
            }
        }

        // MARK: Wallet deeplink interception

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Forward wallet deeplinks (carrying ?uri=wc:…) to the OS so it can open the wallet app.
            if Self.isWalletDeeplink(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // Allow only https (the checkout) and internal about: navigations; block every other
            // scheme regardless of navigation type, so the page cannot drive the OS into arbitrary
            // native schemes (tel:, sms:, intent:, data:, …). The initial https load passes here too.
            let scheme = url.scheme?.lowercased()
            if scheme == "https" || scheme == "about" {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in self?.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in self?.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            reportNavigationFailure(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            reportNavigationFailure(error)
        }

        private func reportNavigationFailure(_ error: Error) {
            // Ignore cancellations — e.g. when we intercept a wallet deeplink and cancel the navigation.
            let isCancelled = (error as NSError).code == NSURLErrorCancelled
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
                if !isCancelled {
                    self?.onFailure("Failed to load checkout: \(error.localizedDescription)")
                }
            }
        }

        // MARK: Helpers

        static func isWalletDeeplink(_ url: URL) -> Bool {
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "uri" })?
                .value?
                .hasPrefix("wc:") ?? false
        }
    }
}
