import Foundation

#if CocoaPods
public extension Foundation.Bundle {
    private class CocoapodsBundle {}

    static var coreModule: Bundle {
        let bundle = Bundle(for: CocoapodsBundle.self)
        let frameworkBundlePath = bundle.path(forResource: "Web3Modal", ofType: "bundle")!
        return Bundle(path: frameworkBundlePath) ?? bundle
    }
}
#else
public extension Foundation.Bundle {
    static var coreModule: Bundle { Bundle.module }
}
#endif
