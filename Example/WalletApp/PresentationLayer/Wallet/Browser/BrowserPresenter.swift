import Foundation
import Combine
import WebKit

final class BrowserPresenter: ObservableObject {

    weak var webView: WKWebView?

    @Published var urlString = "https://react-app.walletconnect.com"

    init() {}

    func loadURLString() {
        if let url = URL(string: urlString) {
            webView?.load(URLRequest(url: url.sanitise))
        }
    }

    func reload() {
        webView?.reload()
    }
}

extension URL {
    var sanitise: URL {
        if var components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            if components.scheme == nil {
                components.scheme = "https"
            }
            return components.url ?? self
        }
        return self
    }
}
