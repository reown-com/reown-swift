import Foundation

class RelayUrlFactory {
    private let relayHost: String
    private let projectId: String

    init(
        relayHost: String,
        projectId: String
    ) {
        self.relayHost = relayHost
        self.projectId = projectId
    }

    func create(bundleId: String?) -> URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = relayHost
        components.queryItems = [
            URLQueryItem(name: "projectId", value: projectId)
        ]
        if let bundleId = Bundle.main.bundleIdentifier {
            components.queryItems?.append(URLQueryItem(name: "bundleId", value: bundleId))
        }
        return components.url!
    }
}
