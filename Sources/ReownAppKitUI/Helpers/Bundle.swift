import Foundation


#if CocoaPods
public extension Foundation.Bundle {
    private class CocoapodsBundle {}
    
    static var module: Bundle {
        let bundle = Bundle(for: CocoapodsBundle.self)
        let frameworkBundlePath = bundle.path(forResource: "Web3ModalUI", ofType: "bundle")!
        return Bundle(path: frameworkBundlePath) ?? bundle
    }
}

#endif
