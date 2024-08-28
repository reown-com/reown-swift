#if os(iOS)
import UIKit
#endif
import Foundation

enum EnvironmentInfo {
    
    static var sdkVersion: String {
        "swift-\(packageVersion)/\(operatingSystem)"
    }
    
    static var packageVersion: String {
        guard
            let fileURL = Bundle.coreModule.url(forResource: "PackageConfig", withExtension: "json"),
            let data = try? Data(contentsOf: fileURL),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let version = jsonObject["version"] as? String
        else {
            return "undefined"
        }
        
        return version
    }

    public static var operatingSystem: String {
#if os(iOS)
        return "\(UIDevice.current.systemName)-\(UIDevice.current.systemVersion)"
#elseif os(macOS)
        return "macOS-\(ProcessInfo.processInfo.operatingSystemVersion)"
#elseif os(tvOS)
        return "tvOS-\(ProcessInfo.processInfo.operatingSystemVersion)"
#endif
    }
}
