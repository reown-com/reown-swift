import Foundation
import Combine
import ReownWalletKit

// MARK: - Balance Response Models
struct BalanceResponse: Codable {
    let balances: [TokenBalance]
}

struct TokenBalance: Codable {
    let name: String
    let symbol: String
    let chainId: String
    let address: String?
    let value: Double
    let price: Double
    let quantity: TokenQuantity
    let iconUrl: String
}

struct TokenQuantity: Codable {
    let decimals: String
    let numeric: String
}

// MARK: - Balance Provider
class EthBalanceProvider {
    enum Errors: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case apiError(String)
        case tokenNotFound(String)
    }

    private let sdkVersion: String = "react-solana-5.1.8"

    private let baseURL: String = "https://rpc.walletconnect.com/v1"
    private let projectId: String = InputConfig.projectId

    private var session: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }

    
    /// Fetches balance and price for the given address, chain and token name
    /// - Parameters:
    ///   - address: The wallet address
    ///   - chainId: The blockchain
    ///   - tokenSymbol: The token symbol to filter for (e.g. "ETH", "USDC")
    /// - Returns: A tuple containing the balance and dollar value
    func fetchBalance(address: String, chainId: Blockchain, tokenSymbol: String = "ETH") async throws -> (balance: String, dollarValue: String) {
        // Make sure we have the address with the 0x prefix
        let formattedAddress = address.hasPrefix("0x") ? address : "0x" + address
        
        // Create URL with URLComponents
        var urlComponents = URLComponents(string: "\(baseURL)/account/\(formattedAddress)/balance")
        
        // Add query parameters
        urlComponents?.queryItems = [
            URLQueryItem(name: "currency", value: "usd"),
            URLQueryItem(name: "projectId", value: projectId),
            URLQueryItem(name: "chainId", value: chainId.absoluteString)
        ]
        
        guard let url = urlComponents?.url else {
            throw Errors.invalidURL
        }
        
        // Create request with necessary headers
        var request = URLRequest(url: url)
        request.addValue(sdkVersion, forHTTPHeaderField: "x-sdk-version")
        
        do {
            // Make the request
            let (data, response) = try await session.data(for: request)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw Errors.apiError("Invalid response")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw Errors.apiError("API error with status code: \(httpResponse.statusCode)")
            }
            
            // Decode the response
            let balanceResponse = try JSONDecoder().decode(BalanceResponse.self, from: data)
            
            // Find the requested token in the balances array by symbol
            guard let tokenBalance = balanceResponse.balances.first(where: { 
                // Match by symbol, case insensitive
                $0.symbol.caseInsensitiveCompare(tokenSymbol) == .orderedSame
            }) else {
                throw Errors.tokenNotFound("Token with symbol \(tokenSymbol) not found in balances")
            }
            
            // Format the balance and dollar value
            // Parse the numeric value to a Double for formatting
            if let numericValue = Double(tokenBalance.quantity.numeric) {
                // Format with exactly 5 decimal places
                let formattedBalance = String(format: "%.5f", numericValue)
                let formattedDollarValue = "$\(String(format: "%.2f", tokenBalance.value))"
                
                return (formattedBalance, formattedDollarValue)
            } else {
                // Fallback if parsing fails
                let formattedBalance = tokenBalance.quantity.numeric
                let formattedDollarValue = "$\(String(format: "%.2f", tokenBalance.value))"
                
                return (formattedBalance, formattedDollarValue)
            }
        } catch let decodingError as DecodingError {
            throw Errors.decodingError(decodingError)
        } catch let networkError {
            throw Errors.networkError(networkError)
        }
    }
} 
