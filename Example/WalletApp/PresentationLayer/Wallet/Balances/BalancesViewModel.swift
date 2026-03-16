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
    let chainId: String
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

/// Notification posted when a payment is completed successfully
extension Notification.Name {
    static let paymentCompleted = Notification.Name("paymentCompleted")
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
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    lazy var scanHandler = ScanOptionsHandler(
        onScan: { [weak self] in self?.presentScanCamera() },
        onUri: { [weak self] in self?.handleScannedOrPastedUri($0) }
    )

    // MARK: - Dependencies

    private let app: Application
    private let importAccount: ImportAccount
    weak var viewController: UIViewController?

    // MARK: - Auto-refresh

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private static let refreshInterval: TimeInterval = 10.0
    
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
    
    // MARK: - Init

    init(app: Application, importAccount: ImportAccount) {
        self.app = app
        self.importAccount = importAccount
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
        fetchAllBalances()
        startAutoRefresh()
    }

    func onDisappear() {
//        print("[Balance] onDisappear")
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
        AlertPresenter.present(message: "Address copied", type: .success)
    }

    // MARK: - Auto-refresh

    private func startAutoRefresh() {
        stopAutoRefresh()
//        print("[Balance] Starting auto-refresh timer (interval: \(Self.refreshInterval)s)")
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
//            print("[Balance] Auto-refresh timer fired")
            self?.fetchAllBalances()
        }
    }

    private func stopAutoRefresh() {
        if refreshTimer != nil {
//            print("[Balance] Stopping auto-refresh timer")
        }
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
    
    // MARK: - Navigation Actions

    private func presentScanCamera() {
        guard let viewController = viewController else { return }
        ScanModule.create(app: app, onValue: { [weak self] uriString in
            self?.viewController?.navigationController?.dismiss(animated: true)
            self?.handleScannedOrPastedUri(uriString)
        }, onError: { [weak self] error in
            print("Scan error: \(error.localizedDescription)")
            self?.viewController?.navigationController?.dismiss(animated: true)
        })
        .wrapToNavigationController()
        .present(from: viewController)
    }

    private func dismissPresented() {
        UIApplication.currentWindow.rootViewController?.dismiss(animated: true)
    }

    private func dismissToPresent(then completion: @escaping () -> Void) {
        if let presented = UIApplication.currentWindow.rootViewController?.presentedViewController {
            presented.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchAllBalances() {
        Task { await fetchAllBalancesAsync() }
    }

    private func fetchAllBalancesAsync() async {
        do {
            // Build URL with query parameters
            var components = URLComponents(string: "https://rpc.walletconnect.org/v1/account/\(walletAddress)/balance")
            components?.queryItems = [
                URLQueryItem(name: "projectId", value: InputConfig.projectId),
                URLQueryItem(name: "currency", value: "usd")
            ]

            guard let url = components?.url else {
                throw URLError(.badURL)
            }

            // Create request with required headers
            var request = URLRequest(url: url)
            request.setValue("appkit", forHTTPHeaderField: "x-sdk-type")
            request.setValue("reown-swift-1.0", forHTTPHeaderField: "x-sdk-version")
            request.setValue("https://reown.com", forHTTPHeaderField: "Origin")

            // Fetch and decode
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(BalanceAPIResponse.self, from: data)

            // Filter for USDC and EURC tokens
            let usdcTokens = response.balances.filter { $0.symbol == "USDC" }
            let eurcTokens = response.balances.filter { $0.symbol == "EURC" }

            // Merge API balances with native token fallbacks
            var balanceMap: [String: TokenBalance] = [:]
            // Start with native token defaults (zero balance)
            for native in mainnetNativeTokens {
                balanceMap[native.id] = native
            }
            // Override with actual API balances
            for token in response.balances {
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
    
    private func handleScannedOrPastedUri(_ uriString: String) {
        // Check if it's a WalletConnect Pay URL
        if WalletKit.isPaymentLink(uriString) {
            startPayFlow(paymentLink: uriString)
            return
        }
        
        // Otherwise, try to parse as WalletConnect pairing URI
        do {
            let uri = try WalletConnectURI(uriString: uriString)
            pair(uri: uri)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func pair(uri: WalletConnectURI) {
        Task { @MainActor in
            do {
                try await WalletKit.instance.pair(uri: uri)
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    private func startPayFlow(paymentLink: String) {
        guard let rootVC = UIApplication.currentWindow.rootViewController else { return }
        let address = importAccount.account.address
        let accounts = [
            "eip155:1:\(address)",
            "eip155:137:\(address)",
            "eip155:8453:\(address)"
        ]

        PayModule.create(
            app: app,
            paymentLink: paymentLink,
            accounts: accounts,
            importAccount: importAccount
        )
        .presentFullScreen(from: rootVC, transparentBackground: true)
    }
}

// MARK: - SceneViewModel Conformance

extension BalancesViewModel: SceneViewModel {
    var sceneTitle: String? {
        return nil
    }

    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .never
    }

    var isNavigationBarHidden: Bool {
        return true
    }
}

// Import WalletConnectURI and WalletKit
import ReownWalletKit


