import Foundation
import Combine
@preconcurrency import ReownWalletKit
import BigInt

enum StableCoinChoice: String, CaseIterable {
    case usdc = "USDC"
    case usdt = "USDT"
    case usds = "USDS"
}

final class SendStableCoinPresenter: ObservableObject, SceneViewModel {
    // MARK: - Published Properties

    @Published var selectedNetwork: L2 = .Base {
        didSet {
            // Whenever the user changes networks, refetch balances
            fetchAllBalances()
        }
    }
    /// Which stablecoin to send
    @Published var stableCoinChoice: StableCoinChoice = .usdc {
        didSet {
            // Check for unsupported combinations
            if selectedNetwork == .Base {
                if stableCoinChoice == .usdt {
                    AlertPresenter.present(
                        message: "USDT is not supported on Base.",
                        type: .error
                    )
                } else if stableCoinChoice == .usds {
                    AlertPresenter.present(
                        message: "USDS is not supported on Base.",
                        type: .error
                    )
                }
            }
        }
    }

    /// Recipient address or ENS
    @Published var recipient: String = ""

    /// Amount to send (in "human-readable" format, e.g. "1.0" for 1 USDC)
    @Published var amount: String = "1"

    /// When true, shows the success sheet
    @Published var transactionCompleted: Bool = false
    @Published var transactionResult: String? = nil

    /// String displayed for USDC balance
    @Published var usdcBalance: String = "0.00"
    /// String displayed for USDT balance
    @Published var usdtBalance: String = "0.00"
    /// String displayed for USDS balance
    @Published var usdsBalance: String = "0.00"
    /// Combined top-level balance (USDC + USDT + USDS)
    @Published var combinedBalance: String = "0.00"

    let router: SendStableCoinRouter
    let importAccount: ImportAccount

    // MARK: - Private

    private let userDefaults = UserDefaults.standard
    private let recipientKey = "lastStableCoinRecipient"

    // MARK: - Init

    init(router: SendStableCoinRouter, importAccount: ImportAccount) {
        self.router = router
        self.importAccount = importAccount

        // 1) Load the last used recipient from UserDefaults
        let savedRecipient = userDefaults.string(forKey: recipientKey) ?? ""
        self.recipient = savedRecipient

        // Fetch initial balances for the default selectedNetwork
        fetchAllBalances()
    }

    /// Sets the chosen network and triggers a refresh
    func set(network: L2) {
        selectedNetwork = network
    }

    // MARK: - Fetch Balances

    /// Fetch both USDC and USDT balances, compute combined, update UI
    private func fetchAllBalances() {
        let chainString = selectedNetwork.chainId.absoluteString
        let owner = importAccount.account.address

        Task {
            do {
                // 1) Fetch raw hex balances
                let usdcHex = try await WalletKit.instance.erc20Balance(
                    chainId: chainString,
                    token: selectedNetwork.usdcContractAddress,
                    owner: owner
                )
                let usdtHex = try await WalletKit.instance.erc20Balance(
                    chainId: chainString,
                    token: selectedNetwork.usdtContractAddress,
                    owner: owner
                )
                
                // Get USDS balance (if supported on this network)
                var usdsHex = "0x0"
                if !selectedNetwork.usdsContractAddress.isEmpty {
                    usdsHex = try await WalletKit.instance.erc20Balance(
                        chainId: chainString,
                        token: selectedNetwork.usdsContractAddress,
                        owner: owner
                    )
                }

                // 2) Convert both from hex → Decimal (accounting for 6 decimals in each token)
                let usdcDecimal = parseHexBalance(usdcHex, decimals: 6)
                let usdtDecimal = parseHexBalance(usdtHex, decimals: 6)
                let usdsDecimal = parseHexBalance(usdsHex, decimals: 6)

                // 3) Combine them
                let combined = usdcDecimal + usdtDecimal + usdsDecimal

                // 4) Update published properties on MainActor
                await MainActor.run {
                    self.usdcBalance = formatDecimal(usdcDecimal)
                    self.usdtBalance = formatDecimal(usdtDecimal)
                    self.usdsBalance = formatDecimal(usdsDecimal)
                    self.combinedBalance = formatDecimal(combined)
                }
            } catch {
                // On error, set them to 0.00
                AlertPresenter.present(message: error.localizedDescription, type: .error)
                await MainActor.run {
                    self.usdcBalance = "0.00"
                    self.usdtBalance = "0.00"
                    self.usdsBalance = "0.00"
                    self.combinedBalance = "0.00"
                }
            }
        }
    }

    /// Parse a hex string (e.g. "0x123abc") into Decimal and account for `decimals`.
    private func parseHexBalance(_ hexBalance: String, decimals: Int) -> Decimal {
        let hexStr = hexBalance.hasPrefix("0x")
            ? String(hexBalance.dropFirst(2))
            : hexBalance

        guard let bigUInt = BigUInt(hexStr, radix: 16) else {
            return .zero
        }
        // Convert BigUInt -> Decimal
        let baseDecimal = Decimal(string: bigUInt.description) ?? .zero

        // e.g. USDC/USDT use 6 decimals => divide by 10^6
        let divisor = pow(Decimal(10), decimals)
        return baseDecimal / divisor
    }

    /// Format a Decimal nicely for display (e.g. "123.4567")
    private func formatDecimal(_ value: Decimal) -> String {
        let ns = NSDecimalNumber(decimal: value)
        // For example, max 6 decimal places
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        return formatter.string(from: ns) ?? "0.00"
    }

    // MARK: - Send Transaction

    /// Main send method, which prepares and routes a transaction
    func send() async throws {
        // Check for unsupported combinations
        if selectedNetwork == .Base {
            if stableCoinChoice == .usdt {
                AlertPresenter.present(message: "USDT is not supported on Base.", type: .error)
                return
            } else if stableCoinChoice == .usds {
                AlertPresenter.present(message: "USDS is not supported on Base.", type: .error)
                return
            }
        }

        do {
            let call = try getCall()

            ActivityIndicatorManager.shared.start()

            let routeResponseSuccess = try await WalletKit.instance.ChainAbstraction.prepare(
                chainId: selectedNetwork.chainId.absoluteString,
                from: importAccount.account.address,
                call: call,
                localCurrency: .usd
            )

            await MainActor.run {
                switch routeResponseSuccess {
                case .success(let routeResponse):
                    switch routeResponse {
                    case .available(let UiFileds):
                        // If the route is available, present a CA transaction flow
                        // We consider this a success scenario for saving the recipient
                        self.saveRecipientToUserDefaults()

                        router.presentCATransaction(
                            call: call,
                            from: importAccount.account.address,
                            chainId: selectedNetwork.chainId,
                            importAccount: importAccount,
                            uiFields: UiFileds
                        )
                    case .notRequired:
                        // Possibly handle a scenario where no special routing is needed
                        self.saveRecipientToUserDefaults()
                        AlertPresenter.present(message: "Routing not required", type: .success)
                    }
                case .error(let routeResponseError):
                    // Show an error
                    AlertPresenter.present(message: "Route response error: \(routeResponseError)", type: .error)
                }
            }

            ActivityIndicatorManager.shared.stop()

        } catch {
            await MainActor.run {
                ActivityIndicatorManager.shared.stop()
                AlertPresenter.present(message: "CA error: \(error.localizedDescription)", type: .error)
            }
        }
    }

    /// Constructs the `Call` object to send either USDC or USDT (decimal → base units)
    private func getCall() throws -> Call {
        let eoa = try Account(
            blockchain: selectedNetwork.chainId,
            accountAddress: importAccount.account.address
        )
        let toAccount = try Account(
            blockchain: selectedNetwork.chainId,
            accountAddress: recipient
        )

        // 1) Normalize the decimal separator and try to convert to Decimal
        let normalizedAmount = amount.replacingOccurrences(of: ",", with: ".")
        guard let decimalAmount = Decimal(string: normalizedAmount) else {
            throw NSError(domain: "SendStableCoinPresenter", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid numeric input: \(amount)"
            ])
        }

        // USDC/USDT/USDS => 6 decimals
        let baseUnitsDecimal = decimalAmount * Decimal(1_000_000)

        // Use a number formatter to ensure consistent string conversion
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0 // No decimal places for base units
        formatter.groupingSeparator = "" // No thousand separators
        formatter.decimalSeparator = "." // Force decimal point

        guard let baseUnitsString = formatter.string(from: NSDecimalNumber(decimal: baseUnitsDecimal)) else {
            throw NSError(domain: "SendStableCoinPresenter", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert amount to string"
            ])
        }

        // 2) Determine which contract address to use
        let tokenAddress: String
        switch stableCoinChoice {
        case .usdc:
            tokenAddress = selectedNetwork.usdcContractAddress
        case .usdt:
            tokenAddress = selectedNetwork.usdtContractAddress
        case .usds:
            tokenAddress = selectedNetwork.usdsContractAddress
        }

        // 3) Build the call
        let call = WalletKit.instance.prepareERC20TransferCall(
            erc20Address: tokenAddress,
            to: recipient,
            amount: baseUnitsString
        )
        return call
    }
    /// Persists the latest recipient in UserDefaults
    private func saveRecipientToUserDefaults() {
        userDefaults.set(recipient, forKey: recipientKey)
    }
}
