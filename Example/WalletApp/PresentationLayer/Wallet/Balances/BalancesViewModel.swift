import Foundation
import Combine
import SwiftUI

// MARK: - Blockchain API Response Models

struct BalanceAPIResponse: Codable {
    let balances: [TokenBalance]
}

struct TokenBalance: Codable {
    let name: String
    let symbol: String
    let chainId: String?
    let address: String?
    let value: Double
    let price: Double
    let quantity: TokenQuantity
    let iconUrl: String?

    init(name: String, symbol: String, chainId: String, address: String?, value: Double, price: Double, quantity: TokenQuantity, iconUrl: String?) {
        self.name = name
        self.symbol = symbol
        self.chainId = chainId
        self.address = address
        self.value = value
        self.price = price
        self.quantity = quantity
        self.iconUrl = iconUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        chainId = try container.decodeIfPresent(String.self, forKey: .chainId) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address)
        value = try container.decodeIfPresent(Double.self, forKey: .value) ?? 0
        price = try container.decodeIfPresent(Double.self, forKey: .price) ?? 0
        quantity = try container.decodeIfPresent(TokenQuantity.self, forKey: .quantity) ?? TokenQuantity(decimals: "0", numeric: "0")
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)
    }
}

extension TokenBalance: Identifiable {
    var id: String { "\(chainId)-\(symbol)-\(address ?? "native")" }
}

struct TokenQuantity: Codable {
    let decimals: String
    let numeric: String
}

/// Model representing a chain's USDC balance
struct ChainBalance: Identifiable {
    let id: String
    let chain: USDCChain
    var balance: Decimal
    var error: String?

    init(chain: USDCChain, balance: Decimal = 0, error: String? = nil) {
        self.id = chain.rawValue
        self.chain = chain
        self.balance = balance
        self.error = error
    }

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: balance)) ?? "$0.00"
    }
}

// MARK: - Native Token Defaults

/// Native tokens to always display for EVM addresses, even with zero balance
private let mainnetNativeTokens: [TokenBalance] = [
    TokenBalance(
        name: "Ethereum", symbol: "ETH", chainId: "eip155:1", address: nil,
        value: 0, price: 0,
        quantity: TokenQuantity(decimals: "18", numeric: "0"),
        iconUrl: "https://token-icons.s3.amazonaws.com/eth.png"
    ),
    TokenBalance(
        name: "Polygon", symbol: "POL", chainId: "eip155:137", address: nil,
        value: 0, price: 0,
        quantity: TokenQuantity(decimals: "18", numeric: "0"),
        iconUrl: "https://token-icons.s3.amazonaws.com/0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0.png"
    ),
    TokenBalance(
        name: "BNB", symbol: "BNB", chainId: "eip155:56", address: nil,
        value: 0, price: 0,
        quantity: TokenQuantity(decimals: "18", numeric: "0"),
        iconUrl: "https://token-icons.s3.amazonaws.com/0xb8c77482e45f1f44de1745f52c74426c631bdd52.png"
    ),
    TokenBalance(
        name: "Arbitrum", symbol: "ETH", chainId: "eip155:42161", address: nil,
        value: 0, price: 0,
        quantity: TokenQuantity(decimals: "18", numeric: "0"),
        iconUrl: "https://token-icons.s3.amazonaws.com/eth.png"
    ),
    TokenBalance(
        name: "Base", symbol: "ETH", chainId: "eip155:8453", address: nil,
        value: 0, price: 0,
        quantity: TokenQuantity(decimals: "18", numeric: "0"),
        iconUrl: "https://token-icons.s3.amazonaws.com/eth.png"
    ),
    TokenBalance(
        name: "Optimism", symbol: "ETH", chainId: "eip155:10", address: nil,
        value: 0, price: 0,
        quantity: TokenQuantity(decimals: "18", numeric: "0"),
        iconUrl: "https://token-icons.s3.amazonaws.com/eth.png"
    ),
]

/// Native non-EVM tokens to display when the wallet has the corresponding
/// account, even with zero balance. Each is only seeded into the balance map
/// when its account address exists. The chainId must match the chainId used to
/// fetch that chain's balances so a real balance from the API overrides this
/// zero default (same mechanism as the EVM natives above).
private let solanaNativeToken = TokenBalance(
    name: "Solana", symbol: "SOL",
    chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", address: nil,
    value: 0, price: 0,
    quantity: TokenQuantity(decimals: "9", numeric: "0"),
    iconUrl: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/info/logo.png"
)

private let suiNativeToken = TokenBalance(
    name: "Sui", symbol: "SUI",
    chainId: "sui:mainnet", address: nil,
    value: 0, price: 0,
    quantity: TokenQuantity(decimals: "9", numeric: "0"),
    iconUrl: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/sui/info/logo.png"
)

private let tonNativeToken = TokenBalance(
    name: "TON", symbol: "TON",
    chainId: "ton:-239", address: nil,
    value: 0, price: 0,
    quantity: TokenQuantity(decimals: "9", numeric: "0"),
    iconUrl: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ton/info/logo.png"
)

private let tronNativeToken = TokenBalance(
    name: "TRON", symbol: "TRX",
    chainId: "tron:0x2b6653dc", address: nil,
    value: 0, price: 0,
    quantity: TokenQuantity(decimals: "6", numeric: "0"),
    iconUrl: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/tron/info/logo.png"
)

/// Notification posted when a payment is completed successfully
extension Notification.Name {
    static let paymentCompleted = Notification.Name("paymentCompleted")
    static let paymentLinkDetected = Notification.Name("paymentLinkDetected")
    static let walletImported = Notification.Name("walletImported")
}

/// ViewModel for the Balances screen
final class BalancesViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedTab: Int = 0
    @Published var usdcBalances: [ChainBalance] = USDCChain.allCases.map { ChainBalance(chain: $0) }
    @Published var eurcBalances: [ChainBalance] = USDCChain.eurcChains.map { ChainBalance(chain: $0) }
    @Published var tokenBalances: [TokenBalance] = []
    @Published var isLoading: Bool = true
    @Published var isRefreshing: Bool = false

    lazy var scanHandler = ScanOptionsHandler(
        onScan: { [weak self] in self?.presentScanCamera() },
        onUri: { [weak self] in self?.handleScannedOrPastedUri($0) }
    )

    // MARK: - Dependencies

    private let app: Application
    private let importAccount: ImportAccount

    // MARK: - Auto-refresh

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private static let refreshInterval: TimeInterval = 300.0 // 5 minutes
    /// Timestamp of the last successful balance fetch. `onAppear` fires each time
    /// the Balances tab becomes visible; we only re-fetch when the data is stale
    /// (older than `refreshInterval`). Quick tab switches within the interval
    /// don't hit the expensive balance endpoint, but returning after a while
    /// refreshes once. `nil` until the first successful fetch.
    private var lastSuccessfulFetch: Date?
    
    // MARK: - Computed Properties
    
    var displayedBalances: [ChainBalance] {
        selectedTab == 0 ? usdcBalances : eurcBalances
    }

    var totalBalance: Decimal {
        displayedBalances.reduce(0) { $0 + $1.balance }
    }

    var formattedTotalBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: totalBalance)) ?? "$0.00"
    }

    var tokenLabel: String {
        selectedTab == 0 ? "USDC" : "EURC"
    }
    
    var walletAddress: String {
        importAccount.account.address
    }

    var truncatedAddress: String {
        let address = walletAddress
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    // MARK: - Spam Filtering

    /// Symbols of known spam/airdrop tokens to hide from the balances list.
    /// Matched case-insensitively against the trimmed token symbol.
    private static let spamSymbols: Set<String> = [
        "MANTRA POS", "AMPAR", "ACHIVX", "BASED", "GT", "MY"
    ]

    /// Detects scam/airdrop tokens that abuse the symbol field to advertise a
    /// website (e.g. "USD0 [www.usual.finance]", "ecAVAX - https://invest...",
    /// "www.2base.cfd") or that match a known spam symbol blocklist.
    private static func isSpam(_ token: TokenBalance) -> Bool {
        let symbol = token.symbol
        let lower = symbol.lowercased()

        // Explicit URLs embedded in the symbol.
        if lower.contains("http://") || lower.contains("https://")
            || lower.contains("www.") || lower.contains("://") {
            return true
        }

        // Any domain-like token, e.g. "2base.cfd", "gftpepe.com",
        // "investpulse.org". Legitimate token symbols never contain a "name.tld"
        // segment, so a generic domain match is safe and TLD-agnostic.
        if symbol.range(
            of: #"[a-z0-9][a-z0-9-]*\.[a-z]{2,}"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }

        // Bracketed advertising, e.g. "USD0 [ ... ]" or "VISIT [ GFTPEPE.COM ]".
        if symbol.contains("[") || symbol.contains("]") {
            return true
        }

        // Known spam symbol blocklist.
        let normalized = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if Self.spamSymbols.contains(normalized) {
            return true
        }

        return false
    }

    /// Non-EVM addresses (Solana/Sui/TON/Tron) derived once, off the main thread.
    /// Deriving them involves crypto / Yttrium FFI work — TON in particular spins
    /// up a `TonClient`, which we don't want to construct synchronously during
    /// init (the view model is created from the `@MainActor` coordinator). The
    /// `Task` derives the addresses once and caches its result; the balance fetch
    /// awaits it (off main), and the resolved map is mirrored into the
    /// synchronously-readable `nonEvmAddresses` for per-row rendering. The
    /// underlying keys only change on wallet import, which recreates this view
    /// model (see NavigationCoordinator's `_balancesViewModel = nil`).
    private let nonEvmAddressesTask: Task<[String: String], Never>

    /// Synchronously-readable copy of the derived non-EVM addresses, keyed by
    /// CAIP-2 namespace, for `address(for:)`. Assigned on the main actor inside
    /// the fetch. Non-EVM rows only exist after a fetch (which awaits the
    /// derivation), so this is populated by the time such a row renders.
    /// Main-actor-only access.
    private var nonEvmAddresses: [String: String] = [:]

    private static func deriveNonEvmAddresses() -> [String: String] {
        var result: [String: String] = [:]
        if let address = SolanaAccountStorage().getAddress() { result["solana"] = address }
        if let address = SuiAccountStorage().getAddress() { result["sui"] = address }
        if let address = TonAccountStorage().getAddress() { result["ton"] = address }
        if let address = TronAccountStorage().getAddress() { result["tron"] = address }
        return result
    }

    /// Pick the displayed-and-copied address per row based on the token's CAIP-2
    /// chainId namespace. Non-EVM tokens (Solana, Sui, TON, Tron) show their
    /// own native address; everything else falls back to the EVM address.
    func address(for token: TokenBalance) -> String {
        guard let chainId = token.chainId,
              let namespace = chainId.split(separator: ":").first.map(String.init),
              let native = nonEvmAddresses[namespace] else {
            return walletAddress
        }
        return native
    }

    func truncatedAddress(for token: TokenBalance) -> String {
        let address = address(for: token)
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    func copyAddress(for token: TokenBalance) {
        UIPasteboard.general.string = address(for: token)
        WalletToast.present(message: "Address copied", type: .success)
    }
    
    // MARK: - Init

    init(app: Application, importAccount: ImportAccount) {
        self.app = app
        self.importAccount = importAccount
        // Derive non-EVM addresses off the main thread (TON builds a TonClient);
        // the balance fetch awaits this and mirrors the result into
        // `nonEvmAddresses` for rendering.
        self.nonEvmAddressesTask = Task.detached(priority: .userInitiated) {
            Self.deriveNonEvmAddresses()
        }
        subscribeToPaymentCompletion()
        scanHandler.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    deinit {
        stopAutoRefresh()
    }

    // MARK: - Public Methods

    func onAppear() {
        // Fetch on first appearance, or when the displayed data is stale (older
        // than the refresh interval). Quick tab switches within the interval
        // don't trigger a fetch, keeping load off the expensive balance endpoint;
        // returning after the data has gone stale refreshes once.
        let isStale = lastSuccessfulFetch.map { Date().timeIntervalSince($0) >= Self.refreshInterval } ?? true
        if isStale {
            fetchAllBalances()
        }
        startAutoRefresh()
    }

    func onDisappear() {
        stopAutoRefresh()
    }

    func refresh() async {
        isRefreshing = true
        await fetchAllBalancesAsync()
    }

    func formattedTokenBalance(_ token: TokenBalance) -> String {
        let numeric = Double(token.quantity.numeric) ?? 0
        if numeric == 0 { return "0 \(token.symbol)" }
        if numeric < 0.0001 { return "<0.0001 \(token.symbol)" }
        if numeric < 1 { return "\(String(format: "%.4f", numeric)) \(token.symbol)" }
        if numeric < 1000 { return "\(String(format: "%.2f", numeric)) \(token.symbol)" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: numeric)) ?? String(format: "%.2f", numeric)) \(token.symbol)"
    }

    func copyAddress() {
        UIPasteboard.general.string = walletAddress
        WalletToast.present(message: "Address copied", type: .success)
    }

    // MARK: - Auto-refresh

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.fetchAllBalances()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func subscribeToPaymentCompletion() {
        NotificationCenter.default.publisher(for: .paymentCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
    }
    
    /// Whether NFC reading is available on this device.
    var isNFCAvailable: Bool {
        NFCPaymentReader.isAvailable
    }

    // MARK: - Navigation Actions

    func onScanNFC() {
        NFCPaymentReader.shared.scan { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let urlString):
                    self?.handleScannedOrPastedUri(urlString)
                case .failure(let error):
                    if case NFCPaymentError.cancelled = error { return }
                    WalletToast.present(message: error.localizedDescription, type: .error)
                }
            }
        }
    }

    private func presentScanCamera() {
        // Scan camera is handled via ScanOptionsHandler
    }
    
    // MARK: - Private Methods
    
    private func fetchAllBalances() {
        Task { await fetchAllBalancesAsync() }
    }

    private func fetchAllBalancesAsync() async {
        do {
            // Fetch EVM and non-EVM (Solana/Sui/TON/Tron) balances in parallel.
            // The balance API only accepts one address per call, so we issue one
            // request per chain and merge the results. Each non-EVM fetch is
            // optional — if the wallet has no account for that chain, or the
            // fetch fails, we skip it and the zero-balance native default below
            // keeps the row (and its address) visible.
            let nonEvmAddresses = await nonEvmAddressesTask.value
            let nonEvmAccounts: [(token: TokenBalance, address: String?)] = [
                (solanaNativeToken, nonEvmAddresses["solana"]),
                (suiNativeToken, nonEvmAddresses["sui"]),
                (tonNativeToken, nonEvmAddresses["ton"]),
                (tronNativeToken, nonEvmAddresses["tron"]),
            ]

            async let evmBalances = Self.fetchBalances(for: walletAddress, chainId: nil)
            let nonEvmBalances = await withTaskGroup(of: [TokenBalance].self) { group in
                for account in nonEvmAccounts {
                    guard let address = account.address, !address.isEmpty else { continue }
                    let chainId = account.token.chainId
                    let symbol = account.token.symbol
                    group.addTask {
                        do {
                            return try await Self.fetchBalances(for: address, chainId: chainId)
                        } catch {
                            // A single chain's failure shouldn't block the rest.
                            print("[Balance] \(symbol) fetch failed: \(error.localizedDescription)")
                            return []
                        }
                    }
                }
                var results: [TokenBalance] = []
                for await balances in group {
                    results.append(contentsOf: balances)
                }
                return results
            }
            // Drop scam/airdrop tokens (URLs in symbol, known spam symbols).
            let allApiBalances = (try await evmBalances + nonEvmBalances)
                .filter { !Self.isSpam($0) }

            // Filter for USDC and EURC tokens
            let usdcTokens = allApiBalances.filter { $0.symbol == "USDC" }
            let eurcTokens = allApiBalances.filter { $0.symbol == "EURC" }

            // Merge API balances with native token fallbacks
            var balanceMap: [String: TokenBalance] = [:]
            // Start with native token defaults (zero balance)
            for native in mainnetNativeTokens {
                balanceMap[native.id] = native
            }
            // Always show a native row (zero balance) for each non-EVM chain the
            // wallet has an account for, so its address stays visible even if the
            // API omits it.
            for account in nonEvmAccounts {
                guard let address = account.address, !address.isEmpty else { continue }
                balanceMap[account.token.id] = account.token
            }
            // Override with actual API balances
            for token in allApiBalances {
                balanceMap[token.id] = token
            }
            // Sort: tokens with balance first (by value desc), then zero-balance by name
            let allBalances = balanceMap.values.sorted { a, b in
                let aVal = a.value
                let bVal = b.value
                if aVal != bVal { return aVal > bVal }
                return a.name < b.name
            }

            // Update balances on main thread
            await MainActor.run {
                // Only update if data actually changed to avoid triggering unnecessary re-renders
                let newIds = allBalances.map { $0.id }
                let oldIds = self.tokenBalances.map { $0.id }
                let newValues = allBalances.map { $0.value }
                let oldValues = self.tokenBalances.map { $0.value }
                if newIds != oldIds || newValues != oldValues {
                    print("[Balance] Updating tokenBalances: \(allBalances.count) items")
                    self.tokenBalances = allBalances
                } else {
                    print("[Balance] No change, skipping UI update")
                }

                // Update USDC/EURC balances without triggering @Published if unchanged
                var newUsdc = self.usdcBalances
                for chain in USDCChain.allCases {
                    if let index = newUsdc.firstIndex(where: { $0.chain == chain }),
                       let apiBalance = usdcTokens.first(where: { $0.chainId == chain.chainId }) {
                        newUsdc[index].balance = Decimal(apiBalance.value)
                        newUsdc[index].error = nil
                    } else if let index = newUsdc.firstIndex(where: { $0.chain == chain }) {
                        newUsdc[index].balance = 0
                        newUsdc[index].error = nil
                    }
                }
                if newUsdc.map({ $0.balance }) != self.usdcBalances.map({ $0.balance }) {
                    self.usdcBalances = newUsdc
                }

                var newEurc = self.eurcBalances
                for chain in USDCChain.eurcChains {
                    if let index = newEurc.firstIndex(where: { $0.chain == chain }),
                       let apiBalance = eurcTokens.first(where: { $0.chainId == chain.chainId }) {
                        newEurc[index].balance = Decimal(apiBalance.value)
                        newEurc[index].error = nil
                    } else if let index = newEurc.firstIndex(where: { $0.chain == chain }) {
                        newEurc[index].balance = 0
                        newEurc[index].error = nil
                    }
                }
                if newEurc.map({ $0.balance }) != self.eurcBalances.map({ $0.balance }) {
                    self.eurcBalances = newEurc
                }

                // Mirror the resolved non-EVM addresses for synchronous per-row
                // reads in `address(for:)`. Assigned in the same main-actor block
                // as `tokenBalances`, so the new rows render with the correct
                // addresses rather than the EVM fallback.
                self.nonEvmAddresses = nonEvmAddresses
                self.lastSuccessfulFetch = Date()
                if self.isLoading { self.isLoading = false }
                if self.isRefreshing { self.isRefreshing = false }
            }
        } catch {
            await MainActor.run {
                print("[Balance] Error fetching balances: \(error.localizedDescription)")
                if self.isLoading { self.isLoading = false }
                if self.isRefreshing { self.isRefreshing = false }
            }
        }
    }

    private static func fetchBalances(for address: String, chainId: String?) async throws -> [TokenBalance] {
        var components = URLComponents(string: "https://rpc.walletconnect.org/v1/account/\(address)/balance")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "projectId", value: InputConfig.projectId),
            URLQueryItem(name: "currency", value: "usd")
        ]
        if let chainId {
            queryItems.append(URLQueryItem(name: "chainId", value: chainId))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("appkit", forHTTPHeaderField: "x-sdk-type")
        request.setValue("reown-swift-1.0", forHTTPHeaderField: "x-sdk-version")
        request.setValue("https://reown.com", forHTTPHeaderField: "Origin")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(BalanceAPIResponse.self, from: data).balances
    }

    private func handleScannedOrPastedUri(_ uriString: String) {
        // Check if it's a WalletConnect Pay URL (e.g. pay.walletconnect.com)
        if WalletKit.isPaymentLink(uriString) {
            startPayFlow(paymentLink: uriString)
            return
        }
        
        // Otherwise, try to parse as WalletConnect pairing URI
        do {
            let uri = try WalletConnectURI(uriString: uriString)
            pair(uri: uri)
        } catch {
            WalletToast.present(message: "Invalid link or URI", type: .error)
        }
    }

    private func pair(uri: WalletConnectURI) {
        Task { @MainActor in
            do {
                try await WalletKit.instance.pair(uri: uri)
            } catch {
                WalletToast.present(message: error.localizedDescription, type: .error)
            }
        }
    }
    
    private func startPayFlow(paymentLink: String) {
        NotificationCenter.default.post(name: .paymentLinkDetected, object: paymentLink)
    }
}

import ReownWalletKit
