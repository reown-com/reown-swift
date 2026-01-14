import Foundation
import Combine
import SwiftUI
import YttriumUtilsWrapper

/// Model representing a chain's USDC balance
struct ChainBalance: Identifiable {
    let id: String
    let chain: USDCChain
    var balance: Decimal
    var isLoading: Bool
    var error: String?
    
    init(chain: USDCChain, balance: Decimal = 0, isLoading: Bool = true, error: String? = nil) {
        self.id = chain.rawValue
        self.chain = chain
        self.balance = balance
        self.isLoading = isLoading
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
    
    private static let evmSigningClient: EvmSigningClient = {
        let metadata = PulseMetadata(
            url: nil,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            sdkVersion: "reown-swift-mobile-1.0",
            sdkPlatform: "mobile"
        )
        return EvmSigningClient(projectId: InputConfig.projectId, pulseMetadata: metadata)
    }()
    
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
        stopAutoRefresh()
    }

    func refresh() {
        isRefreshing = true
        fetchAllBalances()
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
            await withTaskGroup(of: (USDCChain, Result<Decimal, Error>).self) { group in
                for chain in USDCChain.allCases {
                    group.addTask {
                        do {
                            let balance = try await self.fetchBalance(for: chain)
                            return (chain, .success(balance))
                        } catch {
                            return (chain, .failure(error))
                        }
                    }
                }
                
                for await (chain, result) in group {
                    await MainActor.run {
                        if let index = self.chainBalances.firstIndex(where: { $0.chain == chain }) {
                            switch result {
                            case .success(let balance):
                                self.chainBalances[index].balance = balance
                                self.chainBalances[index].isLoading = false
                                self.chainBalances[index].error = nil
                            case .failure(let error):
                                self.chainBalances[index].isLoading = false
                                self.chainBalances[index].error = error.localizedDescription
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.isRefreshing = false
            }
        }
    }
    
    private func fetchBalance(for chain: USDCChain) async throws -> Decimal {
        let balanceString = try await Self.evmSigningClient.getTokenBalance(
            chainId: chain.chainId,
            contractAddress: chain.usdcContractAddress,
            walletAddress: walletAddress
        )
        
        // Parse hex or decimal string to Decimal
        // USDC has 6 decimals
        return parseBalance(balanceString, decimals: 6)
    }
    
    private func parseBalance(_ balanceString: String, decimals: Int) -> Decimal {
        let divisor = pow(Decimal(10), decimals)
        
        // Check if it's a hex string (starts with 0x)
        if balanceString.hasPrefix("0x") {
            let cleanedString = String(balanceString.dropFirst(2))
            if let hexValue = UInt64(cleanedString, radix: 16) {
                return Decimal(hexValue) / divisor
            }
        }
        
        // Otherwise, parse as decimal string (the Rust API returns decimal strings)
        if let decimalValue = Decimal(string: balanceString) {
            return decimalValue / divisor
        }
        
        return 0
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


