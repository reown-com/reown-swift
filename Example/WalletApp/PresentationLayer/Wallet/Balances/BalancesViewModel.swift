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
    let iconUrl: String
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

/// Notification posted when a payment is completed successfully
extension Notification.Name {
    static let paymentCompleted = Notification.Name("paymentCompleted")
}

/// ViewModel for the Balances screen
final class BalancesViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var chainBalances: [ChainBalance] = USDCChain.allCases.map { ChainBalance(chain: $0) }
    @Published var isLoading: Bool = true
    @Published var isRefreshing: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    // MARK: - Dependencies

    private let app: Application
    private let importAccount: ImportAccount
    weak var viewController: UIViewController?

    // MARK: - Auto-refresh

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private static let refreshInterval: TimeInterval = 10.0
    
    // MARK: - Computed Properties
    
    var totalBalance: Decimal {
        chainBalances.reduce(0) { $0 + $1.balance }
    }
    
    var formattedTotalBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: totalBalance)) ?? "$0.00"
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

    func refresh() {
//        print("[Balance] Manual refresh triggered")
        isRefreshing = true
        fetchAllBalances()
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
//                print("[Balance] Payment completed notification received - refreshing")
                self?.refresh()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation Actions
    
    func onScanUri() {
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
    
    func onPasteUri() {
        guard let viewController = viewController else { return }
        PasteUriModule.create(app: app, onValue: { [weak self] uriString in
            self?.handleScannedOrPastedUri(uriString)
        }, onError: { [weak self] error in
            print("Paste error: \(error.localizedDescription)")
            self?.viewController?.navigationController?.dismiss(animated: true)
        })
        .presentFullScreen(from: viewController, transparentBackground: true)
    }
    
    func onTestPay() {
        let pasteVC = PastePaymentLinkModule.create(app: app) { [weak self] paymentLink in
            UIApplication.currentWindow.rootViewController?.dismiss(animated: true) {
                self?.startPayFlow(paymentLink: paymentLink)
            }
        } onError: { error in
            print("Payment link error: \(error.localizedDescription)")
        }
        pasteVC.presentFullScreen(from: UIApplication.currentWindow.rootViewController!, transparentBackground: true)
    }
    
    // MARK: - Private Methods
    
    private func fetchAllBalances() {
        Task {
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

                // Filter for USDC tokens only
                let usdcBalances = response.balances.filter { $0.symbol == "USDC" }

                // Update chainBalances on main thread
                await MainActor.run {
                    for chain in USDCChain.allCases {
                        if let index = self.chainBalances.firstIndex(where: { $0.chain == chain }),
                           let apiBalance = usdcBalances.first(where: { $0.chainId == chain.chainId }) {
                            // Use the pre-calculated USD value from API
                            self.chainBalances[index].balance = Decimal(apiBalance.value)
                            self.chainBalances[index].error = nil
                        } else if let index = self.chainBalances.firstIndex(where: { $0.chain == chain }) {
                            // No balance found for this chain - set to 0
                            self.chainBalances[index].balance = 0
                            self.chainBalances[index].error = nil
                        }
                    }
                    self.isLoading = false
                    self.isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    // Set error on all chains
                    for index in self.chainBalances.indices {
                        self.chainBalances[index].error = error.localizedDescription
                    }
                    self.isLoading = false
                    self.isRefreshing = false
                }
            }
        }
    }
    
    private func handleScannedOrPastedUri(_ uriString: String) {
        // Check if it's a WalletConnect Pay URL
        if isPaymentLink(uriString) {
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
    
    private func isPaymentLink(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        return components.queryItems?.contains(where: { $0.name == "pid" }) == true
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
        .presentFullScreen(from: UIApplication.currentWindow.rootViewController!, transparentBackground: true)
    }
}

// MARK: - SceneViewModel Conformance

extension BalancesViewModel: SceneViewModel {
    var sceneTitle: String? {
        return "Balances"
    }
    
    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        return .always
    }
}

// Import WalletConnectURI and WalletKit
import ReownWalletKit


