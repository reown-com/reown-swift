import Foundation

class ClickstreamAnalyticsProvider: AnalyticsProvider {
    private let eventMapper = DefaultAnalyticsEventMapper()

    func track(_ event: AnalyticsEvent) {
        let urlString = analyticsApiUrl()
        let name = eventMapper.eventName(for: event)
        let properties = eventMapper.parameters(for: event)
        let payload = EventPayload(for: name, properties: properties)
        
        guard
            let url = URL(string: "\(urlString)/e")
        else {
            return
        }
        
        Task {
            do {
                let encodedPayload = try JSONEncoder().encode(payload)
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = encodedPayload
                request.setW3MHeaders()
//                request.setValue("com.walletconnect.web3modal.sample", forHTTPHeaderField: "Origin")
                request.setValue("localhost", forHTTPHeaderField: "Origin") // Localhost temporarily
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let (_, _) = try await URLSession.shared.dataWithRetry(for: request, retryPolicy: .init(
                    maxAttempts: 1,
                    initialDelay: 3,
                    multiplier: 3
                ))
            } catch {
                print("Failed posting event \(error)")
            }
        }

    }
    
    private func analyticsApiUrl() -> String {
//        #if DEBUG
//            return "https://analytics-api-cf-workers-staging.walletconnect-v1-bridge.workers.dev"
//        #else
            return "https://pulse.walletconnect.com"
//        #endif
    }
}

struct EventPayload: Codable {
    struct Props: Codable {
        let type: String
        let event: String
        let properties: [String: String]
    }
    let eventId: String
    let url: String
    let domain: String
    let timestamp: UInt64
    let props: Props

    init(for name: String, properties: [String: String]) {
        self.eventId = UUID().uuidString
        self.url = "https://lab.web3modal.com/"
        self.domain = "lab.web3modal.com"
        self.timestamp = UInt64(Date().timeIntervalSince1970)
        
        self.props = Props(
            type: "track",
            event: name,
            properties: properties
        )
    }
}

private extension URLSession {
    
    struct RetryPolicy {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let multiplier: Double
    }

    enum NetworkError: Error {
        case tooManyAttempts
        case networkFailure(Error)
        case invalidStatusCode
    }
    
    func dataWithRetry(for request: URLRequest, retryPolicy: RetryPolicy) async throws -> (Data, URLResponse) {
        var attempts = 0
        var delay = retryPolicy.initialDelay

        while attempts < retryPolicy.maxAttempts {
            do {
                // Attempt the network request
                let (data, response) = try await URLSession.shared.data(for: request)
                // If the request is successful, return the data and response
                
                guard
                    let httpResponse = response as? HTTPURLResponse,
                    (200..<300).contains(httpResponse.statusCode)
                else {
                    throw NetworkError.invalidStatusCode
                }
                
                return (data, response)
            } catch {
                attempts += 1
                if attempts >= retryPolicy.maxAttempts {
                    // If we've reached the max attempts, throw a tooManyAttempts error
                    throw NetworkError.tooManyAttempts
                } else {
                    // If the request fails, wait for the delay before retrying
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= retryPolicy.multiplier // Increase the delay for the next attempt
                }
            }
        }
        // Fallback error, though we should never reach here due to the throw in the loop
        throw NetworkError.tooManyAttempts
    }
}
