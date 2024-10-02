#if os(iOS)
import UIKit
#endif
import Foundation

public enum EnvironmentInfo {

    public static var userAgent: String {
        "\(protocolName)/\(sdkName)/\(operatingSystem)"
    }

    public static var protocolName: String {
        "wc-2"
    }

    public static var sdkName: String {
        "reown-swift-v\(packageVersion)"
    }

    // This method reads the package version from the "PackageConfig.json" file in the bundle
    public static var packageVersion: String {
        guard let configURL = Bundle.resourceBundle.url(forResource: "PackageConfig", withExtension: "json") else {
            fatalError("Unable to find PackageConfig.json in the resource bundle")
        }

        do {
            let jsonData = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(PackageConfig.self, from: jsonData)
            return config.version
        } catch {
            fatalError("Failed to load and decode PackageConfig.json: \(error)")
        }
    }

    public static var operatingSystem: String {
        #if os(iOS)
        return "\(UIDevice.current.systemName)-\(UIDevice.current.systemVersion)"
        #elseif os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS-\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #elseif os(tvOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "tvOS-\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #else
        return "unknownOS"
        #endif
    }
}
