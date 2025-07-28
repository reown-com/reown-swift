//import Foundation
//import Combine
//import ReownWalletKit
//import BigInt
//import SolanaSwift
//import TweetNacl
//
//final class SendEthereumPresenter: ObservableObject, SceneViewModel {
//    // MARK: - Error Types
//    
//    enum Errors: Error {
//        case invalidInput(String)
//        case networkError(String)
//    }
//    
//    // MARK: - Published Properties
//    
//    @Published var selectedNetwork: Chain = .Arbitrium {
//        didSet {
//            // Check if Solana was selected and if so, revert and show error
//            if selectedNetwork == .Solana {
//                AlertPresenter.present(
//                    message: "Sending ETH is not supported on Solana network.",
//                    type: .error
//                )
//                // Revert to previous network
//                selectedNetwork = oldValue
//                return
//            }
//            
//            // Whenever the user changes networks, refetch balances
//            fetchEthBalance()
//        }
//    }
//    
//    /// Recipient address or ENS
//    @Published var recipient: String = ""
//    
//    /// Amount to send (in "human-readable" format, e.g. "0.1" for 0.1 ETH)
//    @Published var amount: String = "0.01"
//    
//    /// String displayed for ETH balance
//    @Published var ethBalance: String = "0.00"
//    
//    /// Dollar value of the ETH balance
//    @Published var ethDollarValue: String = "$0.00"
//    
//    /// When true, shows the success sheet
//    @Published var transactionCompleted: Bool = false
//    @Published var transactionResult: String? = nil
//    
//    let router: SendEthereumRouter
//    let importAccount: ImportAccount
//    
//    // MARK: - Private
//    
//    private let userDefaults = UserDefaults.standard
//    private let recipientKey = "lastEthRecipient"
//    private let balanceProvider = EthBalanceProvider()
//    
//    // MARK: - Init
//    
//    init(router: SendEthereumRouter, importAccount: ImportAccount) {
//        self.router = router
//        self.importAccount = importAccount
//        
//        // Load the last used recipient from UserDefaults
//        let savedRecipient = userDefaults.string(forKey: recipientKey) ?? ""
//        self.recipient = savedRecipient
//        
//        // Fetch initial balance for the default selectedNetwork
//        fetchEthBalance()
//    }
//    
//    /// Sets the chosen network and triggers a refresh
//    func set(network: Chain) {
//        selectedNetwork = network
//    }
//    
//    // MARK: - Fetch Balance
//    
//    /// Fetch ETH balance for the selected network
//    private func fetchEthBalance() {
//        Task {
//            do {
//                // Attempt to fetch the real balance from the API
//                let address = importAccount.account.address
//                
//                let (balance, dollarValue) = try await balanceProvider.fetchBalance(
//                    address: address,
//                    chainId: selectedNetwork.chainId,
//                    tokenSymbol: "ETH"
//                )
//                
//                await MainActor.run {
//                    self.ethBalance = balance
//                    self.ethDollarValue = dollarValue
//                }
//            } catch {
//                // Set default values in case of error
//                print("Error fetching ETH balance: \(error.localizedDescription)")
//                AlertPresenter.present(message: "Error fetching ETH balance", type: .error)
//
//                await MainActor.run {
//                    self.ethBalance = "0.00"
//                    self.ethDollarValue = "$0.00"
//                }
//            }
//        }
//    }
//    
//    /// Parse a hex string (e.g. "0x123abc") into Decimal and account for `decimals`.
//    private func parseHexBalance(_ hexBalance: String, decimals: Int) -> Decimal {
//        let hexStr = hexBalance.hasPrefix("0x")
//            ? String(hexBalance.dropFirst(2))
//            : hexBalance
//        
//        guard let bigUInt = BigUInt(hexStr, radix: 16) else {
//            return .zero
//        }
//        // Convert BigUInt -> Decimal
//        let baseDecimal = Decimal(string: bigUInt.description) ?? .zero
//        
//        // ETH uses 18 decimals
//        let divisor = pow(Decimal(10), decimals)
//        return baseDecimal / divisor
//    }
//    
//    /// Format a Decimal nicely for display (e.g. "123.4567")
//    private func formatDecimal(_ value: Decimal) -> String {
//        let ns = NSDecimalNumber(decimal: value)
//        // For ETH, we can show more decimal places than for stablecoins
//        let formatter = NumberFormatter()
//        formatter.minimumFractionDigits = 0
//        formatter.maximumFractionDigits = 8
//        formatter.numberStyle = .decimal
//        return formatter.string(from: ns) ?? "0.00"
//    }
//    
//    // MARK: - Send Transaction
//    
//    /// Main send method, which prepares and routes a transaction
//    func send() async throws {
//        // Double-check that we're not attempting to send on Solana
//        if selectedNetwork == .Solana {
//            await MainActor.run {
//                AlertPresenter.present(
//                    message: "Sending ETH is not supported on Solana network.",
//                    type: .error
//                )
//            }
//            return
//        }
//        
//        // Chain abstraction sending commented out - not available
//        await MainActor.run {
//            AlertPresenter.present(
//                message: "Chain abstraction transfers are currently disabled.",
//                type: .error
//            )
//        }
//        return
//
//        // Chain abstraction code commented out
//        /*
//        do {
//            let call = try getCall()
//            
//            ActivityIndicatorManager.shared.start()
//            
//            // Get the Solana account address (optional)
//            let solanaAccount = SolanaAccountStorage().getCaip10Account()?.absoluteString
//            let eip155Account = importAccount.account.absoluteString
//            
//            // Create an array with only non-nil accounts
//            var accounts = [eip155Account]
//            if let solanaAccount = solanaAccount {
//                accounts.append(solanaAccount)
//            }
//            
//            let routeResponseSuccess = try await WalletKit.instance.ChainAbstraction.prepare(
//                chainId: selectedNetwork.chainId.absoluteString,
//                from: importAccount.account.address,
//                call: call,
//                accounts: accounts,
//                localCurrency: .usd
//            )
//            
//            await MainActor.run {
//                switch routeResponseSuccess {
//                case .success(let routeResponse):
//                    switch routeResponse {
//                    case .available(let uiFields):
//                        // If the route is available, present a CA transaction flow
//                        self.saveRecipientToUserDefaults()
//                        
//                        router.presentCATransaction(
//                            call: call,
//                            from: importAccount.account.address,
//                            chainId: selectedNetwork.chainId,
//                            importAccount: importAccount,
//                            uiFields: uiFields
//                        )
//                    case .notRequired:
//                        // Possibly handle a scenario where no special routing is needed
//                        self.saveRecipientToUserDefaults()
//                        AlertPresenter.present(message: "Routing not required", type: .success)
//                    }
//                case .error(let routeResponseError):
//                    // Show an error
//                    AlertPresenter.present(message: "Route response error: \(routeResponseError)", type: .error)
//                }
//            }
//            
//            ActivityIndicatorManager.shared.stop()
//            
//        } catch {
//            await MainActor.run {
//                ActivityIndicatorManager.shared.stop()
//                AlertPresenter.present(message: "CA error: \(error.localizedDescription)", type: .error)
//            }
//        }
//        */
//    }
//    
//    /// Constructs the `Call` object to send ETH
//    private func getCall() throws -> Call {
//        // 1) Normalize the decimal separator and try to convert to Decimal
//        let normalizedAmount = amount.replacingOccurrences(of: ",", with: ".")
//        guard let decimalAmount = Decimal(string: normalizedAmount) else {
//            throw Errors.invalidInput("Invalid numeric input: \(amount)")
//        }
//        
//        // ETH uses 18 decimals
//        let decimalPlaces = 18
//        let baseUnitsDecimal = decimalAmount * pow(Decimal(10), decimalPlaces)
//        
//        // Convert to BigUInt
//        guard let baseUnitsBigInt = BigUInt(baseUnitsDecimal.description) else {
//            throw Errors.invalidInput("Failed to convert amount to BigUInt")
//        }
//        
//        // Convert to hex string with "0x" prefix
//        let hexValue = "0x" + String(baseUnitsBigInt, radix: 16)
//        
//        // For ETH transfers, we use a standard call with empty data
//        return Call(
//            to: recipient,
//            value: hexValue,
//            input: "0x"
//        )
//    }
//    
//    /// Persists the latest recipient in UserDefaults
//    private func saveRecipientToUserDefaults() {
//        userDefaults.set(recipient, forKey: recipientKey)
//    }
//} 
