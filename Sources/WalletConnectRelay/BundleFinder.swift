import Foundation

private class BundleFinder {}

extension Foundation.Bundle {
    /// Returns the resource bundle associated with the current Swift module.
    static var resourceBundle: Bundle = {
        let bundleName = "reown_WalletConnectRelay"
        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,
            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: BundleFinder.self).resourceURL,
            // For command-line tools.
            Bundle.main.bundleURL,
            // Bundle should be present here when running tests.
            Bundle(for: BundleFinder.self).resourceURL?
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent(),
            // Other possibilities
            Bundle(for: BundleFinder.self).resourceURL?
                .deletingLastPathComponent()
                .deletingLastPathComponent(),
        ]

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }

        // If we can't find the bundle, fall back to the module bundle if available
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleFinder.self)
        #endif
    }()
}
