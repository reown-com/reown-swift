import Foundation

/// A model class for Solana token balance responses
struct SolanaTokenBalance: Codable {
    let name: String
    let symbol: String
    let chainId: String
    let address: String
    let value: Double
    let price: Double
    let quantity: TokenQuantity
    let iconUrl: String

    struct TokenQuantity: Codable {
        let decimals: String
        let numeric: String
    }
}

/// Response model for the balance API
struct SolanaBalanceResponse: Codable {
    let balances: [SolanaTokenBalance]
}

/// Error types for Solana balance operations
enum SolanaBalanceError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noBalanceFound
    case serviceError(Int, String)
}

/// A provider class for fetching Solana token balances
class SolanaBalancesProvider {
    /// The WalletConnect project ID
    private let projectId: String = InputConfig.projectId

    /// The Solana chain ID
    private let chainId: String = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"

    /// The base URL for the WalletConnect RPC
    private let baseURL: String = "https://rpc.walletconnect.com/v1/account"


    /// Fetches Solana token balances for a given wallet address
    /// - Parameters:
    ///   - walletAddress: The Solana wallet address
    ///   - tokenAddresses: Optional array of token addresses to filter the results
    /// - Returns: An array of SolanaTokenBalance objects
    func fetchBalances(
        walletAddress: String,
        tokenAddresses: [String]? = nil
    ) async throws -> [SolanaTokenBalance] {
        // 1. Construct the URL
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(walletAddress)/balance") else {
            throw SolanaBalanceError.invalidURL
        }

        // 2. Add query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "currency", value: "usd"),
            URLQueryItem(name: "projectId", value: projectId),
            URLQueryItem(name: "chainId", value: chainId)
        ]

        guard let url = urlComponents.url else {
            throw SolanaBalanceError.invalidURL
        }

        // 3. Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 4. Make the request
        let (data, response) = try await URLSession.shared.data(for: request)

        // 5. Check the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SolanaBalanceError.networkError(NSError(domain: "HTTP", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SolanaBalanceError.serviceError(httpResponse.statusCode, errorMessage)
        }

        // 6. Decode the response
        do {
            let balanceResponse = try JSONDecoder().decode(SolanaBalanceResponse.self, from: data)

            // 7. Filter by token addresses if specified
            if let tokenAddresses = tokenAddresses, !tokenAddresses.isEmpty {
                let filteredBalances = balanceResponse.balances.filter { balance in
                    tokenAddresses.contains(balance.address)
                }

                if filteredBalances.isEmpty {
                    throw SolanaBalanceError.noBalanceFound
                }

                return filteredBalances
            }

            return balanceResponse.balances
        } catch {
            throw SolanaBalanceError.decodingError(error)
        }
    }

    /// Gets the balance of a specific token as a hex string
    /// - Parameters:
    ///   - walletAddress: The Solana wallet address
    ///   - tokenAddress: The token contract address
    /// - Returns: The balance as a hex string (e.g., "0x123abc")
    func getTokenBalanceAsHex(walletAddress: String, tokenAddress: String) async throws -> String {
        let balances = try await fetchBalances(walletAddress: walletAddress, tokenAddresses: [tokenAddress])

        guard let tokenBalance = balances.first else {
            throw SolanaBalanceError.noBalanceFound
        }

        // Extract the numeric value and decimals
        guard let numericValue = Double(tokenBalance.quantity.numeric),
              let decimals = Int(tokenBalance.quantity.decimals) else {
            throw SolanaBalanceError.decodingError(NSError(domain: "Parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse numeric values"]))
        }

        // Convert to base units (multiply by 10^decimals)
        let baseUnits = numericValue * pow(10, Double(decimals))

        // Convert to integer
        let baseUnitsInt = Int(baseUnits)

        // Convert to hex string with "0x" prefix
        let hexString = "0x" + String(baseUnitsInt, radix: 16)

        return hexString
    }
}
