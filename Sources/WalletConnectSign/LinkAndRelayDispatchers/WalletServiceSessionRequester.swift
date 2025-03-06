import Foundation

/// Class responsible for handling wallet service HTTP requests
final class WalletServiceSessionRequester {
    enum Errors: Error {
        case invalidResponseFormat
        case requestFailed(statusCode: Int, message: String?)
        case responseParsingFailed
        case networkError(Error)
    }

    private let logger: ConsoleLogging
    private let session: URLSession

    init(logger: ConsoleLogging) {
        self.logger = logger
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0 // 30 second timeout
        self.session = URLSession(configuration: config)
    }

    /// Makes an HTTP request to the wallet service and returns the response
    func request(_ request: Request, to url: URL) async throws -> AnyCodable {
        logger.debug("Making wallet service request to: \(url.absoluteString) for method: \(request.method)")

        // Create a JSON-RPC request
        let rpcRequest = RPCRequest(method: request.method, params: request.params, rpcid: request.id)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // Serialize the RPC request to JSON
        let jsonData: Data
        do {
            let encoder = JSONEncoder()
            jsonData = try encoder.encode(rpcRequest)
            urlRequest.httpBody = jsonData
        } catch {
            logger.error("Failed to serialize request body: \(error)")
            throw Errors.responseParsingFailed
        }

        // Make the HTTP request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error during wallet service request: \(error)")
            throw Errors.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type received from wallet service")
            throw Errors.invalidResponseFormat
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message if possible
            var errorMessage: String? = nil
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }
            } catch {
                // Ignore parsing errors for the error message
            }

            logger.error("Wallet service request failed with status code: \(httpResponse.statusCode), message: \(errorMessage ?? "unknown")")
            throw Errors.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse the response
        do {
            // First try to parse as a JSON-RPC response
            let jsonObject = try JSONSerialization.jsonObject(with: data)

            // Check for valid JSON-RPC response format
            if let responseDict = jsonObject as? [String: Any],
               responseDict["jsonrpc"] as? String == "2.0",
               let _ = responseDict["id"] {
                return AnyCodable(any: jsonObject)
            } else {
                logger.error("Invalid JSON-RPC response format")
                throw Errors.invalidResponseFormat
            }
        } catch {
            logger.error("Failed to parse wallet service response: \(error)")
            throw Errors.responseParsingFailed
        }
    }
}
