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

    func create() -> URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = relayHost
        components.queryItems = [
            URLQueryItem(name: "projectId", value: projectId)
        ]
        return components.url!
    }
}
