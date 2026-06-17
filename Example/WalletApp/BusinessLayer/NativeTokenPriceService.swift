import Foundation

struct NativeTokenPrice {
    let price: Double
    let currency: String
}

/// Fetches the spot fiat price for a chain's native token from the WalletConnect
/// blockchain fungible-price API. Mirrors the Kotlin sample's `NativeTokenPriceService`
/// (reown-kotlin PR #385): same endpoint, same native-token placeholder address,
/// per-chain TTL cache, in-flight request dedup.
///
/// Pricing is approximate — used only for previewing gas in fiat on the option
/// rows and summary CTA. Falls back to `nil` on any failure; callers must
/// gracefully degrade.
actor NativeTokenPriceService {
    static let shared = NativeTokenPriceService()

    private static let endpoint = URL(string: "https://rpc.walletconnect.org/v1/fungible/price")!
    private static let nativeTokenAddress = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
    private static let cacheTtl: TimeInterval = 60
    private static let requestTimeout: TimeInterval = 10
    private static let defaultCurrency = "USD"

    private struct CachedPrice {
        let price: Double
        let expiresAt: Date
    }

    private var cache: [String: CachedPrice] = [:]
    private var inFlight: [String: Task<NativeTokenPrice?, Never>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(chainId: String, currency: String = NativeTokenPriceService.defaultCurrency) async -> NativeTokenPrice? {
        let projectId = InputConfig.projectId
        guard !projectId.isEmpty else { return nil }

        let fiat = currency.uppercased()
        let key = "\(fiat):\(chainId)"

        if let cached = cache[key], cached.expiresAt > Date() {
            return NativeTokenPrice(price: cached.price, currency: fiat)
        }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<NativeTokenPrice?, Never> { [projectId] in
            await self.performFetch(chainId: chainId, fiat: fiat, projectId: projectId)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result {
            cache[key] = CachedPrice(price: result.price, expiresAt: Date().addingTimeInterval(Self.cacheTtl))
        }
        return result
    }

    private func performFetch(chainId: String, fiat: String, projectId: String) async -> NativeTokenPrice? {
        let address = "\(chainId):\(Self.nativeTokenAddress)"
        let body = PriceRequest(projectId: projectId, currency: fiat.lowercased(), addresses: [address])
        guard let payload = try? JSONEncoder().encode(body) else { return nil }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            let decoded = try JSONDecoder().decode(PriceResponse.self, from: data)
            guard let entry = decoded.fungibles?.first(where: { $0.address?.lowercased() == address.lowercased() }),
                  let price = entry.price, price.isFinite, price > 0 else {
                return nil
            }
            return NativeTokenPrice(price: price, currency: fiat)
        } catch {
            return nil
        }
    }

    private struct PriceRequest: Encodable {
        let projectId: String
        let currency: String
        let addresses: [String]
    }

    private struct PriceResponse: Decodable {
        let fungibles: [Entry]?

        struct Entry: Decodable {
            let address: String?
            let price: Double?
            let symbol: String?
        }
    }
}
