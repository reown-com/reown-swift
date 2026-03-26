import Foundation

class BuildConfiguration {
    enum Environment: String {
        case debug = "Debug"
        case release = "Release"
    }

    static let shared = BuildConfiguration()

    var environment: Environment

    init() {
        let currentConfiguration = Bundle.main.object(forInfoDictionaryKey: "CONFIGURATION") as! String
        environment = Environment(rawValue: currentConfiguration)!
    }
}
