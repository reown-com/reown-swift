import Foundation
import Combine
@preconcurrency import ReownWalletKit
import BigInt


enum StableCoinChoice: String, CaseIterable {
    case usdc = "USDC"
    case usdt = "USDT"
    case usds = "USDS"
    
    /// Number of decimals for each token
    var decimals: Int {
        switch self {
        case .usdc, .usdt:
            return 6  // USDC and USDT use 6 decimals
        case .usds:
            return 18 // USDS uses 18 decimals
        }
    }
}

final class SendStableCoinPresenter: ObservableObject, SceneViewModel {
    // MARK: - Error Types
    
    enum Errors: Error {
        case invalidInput(String)
        case unsupportedToken(String)
        case noSolanaAccount
        case networkError(String)
        case solanaBalanceError(Error)
    }
    
    // MARK: - Published Properties

    @Published var selectedNetwork: L2 = .Arbitrium {
        didSet {
            // If user switches to Solana, check if we have a Solana account
            if selectedNetwork == .Solana {
                if SolanaAccountStorage().getAddress() == nil {
                    AlertPresenter.present(
                        message: "No Solana account found. Please import a Solana account first.",
                        type: .error
                    )
                    // Revert to previous network
                    selectedNetwork = oldValue
                    return
                }
            }
            
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
                }
                // USDS is supported on Base, no error needed
            } else if selectedNetwork == .Solana {
                if stableCoinChoice == .usds {
                    AlertPresenter.present(
                        message: "USDS is not supported on Solana.",
                        type: .error
                    )
                    stableCoinChoice = .usdc
                }
            } else {
                // Not on Base or Solana - check if USDS was selected
                if stableCoinChoice == .usds {
                    AlertPresenter.present(
                        message: "USDS is only supported on Base.",
                        type: .error
                    )
                    stableCoinChoice = .usdc // Revert to USDC
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
        
        // Determine owner based on network type
        let owner: String
        if selectedNetwork == .Solana {
            // For Solana, use the Solana account address
            guard let solanaOwner = SolanaAccountStorage().getAddress() else {
                AlertPresenter.present(message: "No Solana account found", type: .error)
                return
            }
            owner = solanaOwner
        } else {
            // For EVM chains, use the importAccount address
            owner = importAccount.account.address
        }

        Task {
            do {
                // Variables to store balances
                var usdcHex = "0x0"
                var usdtHex = "0x0"
                var usdsHex = "0x0"
                
                if selectedNetwork == .Solana {
                    // For Solana, use the solanaBalance method to fetch both tokens at once
                    let tokenAddresses = [
                        selectedNetwork.usdcContractAddress,
                        selectedNetwork.usdtContractAddress
                    ]
                    fetchSolanaBalances(tokenAddresses: tokenAddresses, owner: owner)
                    
                    // Return default values immediately while async fetch happens
                    usdcHex = "0x0"
                    usdtHex = "0x0"
                } else {
                    // For EVM chains, use erc20Balance
                    usdcHex = try await WalletKit.instance.erc20Balance(
                        chainId: chainString,
                        token: selectedNetwork.usdcContractAddress,
                        owner: owner
                    )
                    usdtHex = try await WalletKit.instance.erc20Balance(
                        chainId: chainString,
                        token: selectedNetwork.usdtContractAddress,
                        owner: owner
                    )
                    
                    // Get USDS balance (if supported on this network)
                    if !selectedNetwork.usdsContractAddress.isEmpty {
                        usdsHex = try await WalletKit.instance.erc20Balance(
                            chainId: chainString,
                            token: selectedNetwork.usdsContractAddress,
                            owner: owner
                        )
                    }
                }

                // 2) Convert hex balances to Decimal with appropriate decimals
                let usdcDecimal = parseHexBalance(usdcHex, decimals: 6)
                let usdtDecimal = parseHexBalance(usdtHex, decimals: 6)
                let usdsDecimal = parseHexBalance(usdsHex, decimals: 18)  // USDS has 18 decimals

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
    
    /// Fetches Solana token balances for multiple tokens in a single API call
    private func fetchSolanaBalances(tokenAddresses: [String], owner: String) {
        Task {
            do {
                let provider = SolanaBalancesProvider()
                let balances = try await provider.fetchBalances(
                    walletAddress: owner,
                    tokenAddresses: tokenAddresses
                )
                
                // Process all returned balances and update the UI directly
                for balance in balances {
                    // Convert the numeric value to hex format directly
                    // This avoids making additional API calls
                    
                    if let numericValue = Double(balance.quantity.numeric),
                       let decimals = Int(balance.quantity.decimals) {
                        
                        // Convert to base units (multiply by 10^decimals)
                        let baseUnits = numericValue * pow(10, Double(decimals))
                        
                        // Convert to integer
                        let baseUnitsInt = Int(baseUnits)
                        
                        // Convert to hex string with "0x" prefix
                        let hexBalance = "0x" + String(baseUnitsInt, radix: 16)
                        
                        // Update the UI with the calculated hex balance
                        await updateTokenBalance(token: balance.address, balance: hexBalance)
                    }
                }
            } catch SolanaBalanceError.noBalanceFound {
                await MainActor.run {
                    AlertPresenter.present(
                        message: "No stablecoins found in this Solana wallet.",
                        type: .warning
                    )
                }
            } catch SolanaBalanceError.serviceError(let code, _) {
                await MainActor.run {
                    AlertPresenter.present(
                        message: "Solana network error (code: \(code)). Using cached balances.",
                        type: .error
                    )
                }
            } catch {
                print("Error fetching Solana balances: \(error)")
                await MainActor.run {
                    AlertPresenter.present(
                        message: "Could not fetch Solana balances: \(error.localizedDescription)",
                        type: .error
                    )
                }
            }
        }
    }
    
    /// Placeholder method for backward compatibility - delegating to fetchSolanaBalances
    private func solanaBalance(token: String, owner: String) -> String {
        // This method is kept for compatibility, but should not be used directly
        // Instead, use fetchSolanaBalances with multiple token addresses
        fetchSolanaBalances(tokenAddresses: [token], owner: owner)
        return "0x0"
    }
    
    /// Updates the specific token balance based on the contract address
    @MainActor
    private func updateTokenBalance(token: String, balance: String) {
        // Determine which token balance to update based on the contract address
        if token == selectedNetwork.usdcContractAddress {
            let decimal = parseHexBalance(balance, decimals: 6)
            self.usdcBalance = formatDecimal(decimal)
            updateCombinedBalance()
        } else if token == selectedNetwork.usdtContractAddress {
            let decimal = parseHexBalance(balance, decimals: 6)
            self.usdtBalance = formatDecimal(decimal)
            updateCombinedBalance()
        } else if token == selectedNetwork.usdsContractAddress {
            let decimal = parseHexBalance(balance, decimals: 18)
            self.usdsBalance = formatDecimal(decimal)
            updateCombinedBalance()
        }
    }
    
    /// Recalculates the combined balance from the individual token balances
    @MainActor
    private func updateCombinedBalance() {
        // Convert string balances back to Decimal for calculation
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        let usdcDecimal = Decimal(string: usdcBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
        let usdtDecimal = Decimal(string: usdtBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
        let usdsDecimal = Decimal(string: usdsBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        // Combine them
        let combined = usdcDecimal + usdtDecimal + usdsDecimal
        
        // Update the combined balance
        self.combinedBalance = formatDecimal(combined)
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
                AlertPresenter.present(message: "DAI is not supported on Base.", type: .error)
                return
            }
        } else if selectedNetwork == .Solana {
            // Solana sending is not supported yet
            AlertPresenter.present(message: "Sending on Solana network not supported", type: .error)
            return
        }

        do {
            let call = try getCall()

            ActivityIndicatorManager.shared.start()

            // Get the Solana account address (optional)
            let solanaAccount = SolanaAccountStorage().getCaip10Account()?.absoluteString
            let eip155Account = importAccount.account.absoluteString

            
            // Create an array with only non-nil accounts
            var accounts = [eip155Account]
            if let solanaAccount = solanaAccount {
                accounts.append(solanaAccount)
            }

            let routeResponseSuccess = try await WalletKit.instance.ChainAbstraction.prepare(
                chainId: selectedNetwork.chainId.absoluteString,
                from: importAccount.account.address,
                call: call, 
                accounts: accounts,
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
        // Handle Solana differently from EVM chains
        if selectedNetwork == .Solana {
            // Solana sending is not supported in this version
            throw Errors.unsupportedToken("Sending on Solana network not supported")
        } else {
            return try getEVMCall()
        }
    }
    
    /// Constructs a Call object for EVM token transfers
    private func getEVMCall() throws -> Call {
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
            throw Errors.invalidInput("Invalid numeric input: \(amount)")
        }

        // Convert to base units using the appropriate number of decimals
        let decimalPlaces = stableCoinChoice.decimals
        let baseUnitsDecimal = decimalAmount * pow(10, decimalPlaces)

        // Use a number formatter to ensure consistent string conversion
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0 // No decimal places for base units
        formatter.groupingSeparator = "" // No thousand separators
        formatter.decimalSeparator = "." // Force decimal point

        guard let baseUnitsString = formatter.string(from: NSDecimalNumber(decimal: baseUnitsDecimal)) else {
            throw Errors.invalidInput("Failed to convert amount to string")
        }

        // 2) Determine which contract address to use
        let tokenAddress: String
        switch stableCoinChoice {
        case .usdc:
            tokenAddress = selectedNetwork.usdcContractAddress
        case .usdt:
            tokenAddress = selectedNetwork.usdtContractAddress
        case .usds:
            if selectedNetwork.usdsContractAddress.isEmpty {
                throw Errors.unsupportedToken("DAI is not supported on this network")
            }
            tokenAddress = selectedNetwork.usdsContractAddress
        }

        // 3) Build the call for EVM
        return WalletKit.instance.prepareERC20TransferCall(
            erc20Address: tokenAddress,
            to: recipient,
            amount: baseUnitsString
        )
    }

    /// Persists the latest recipient in UserDefaults
    private func saveRecipientToUserDefaults() {
        userDefaults.set(recipient, forKey: recipientKey)
    }
}
