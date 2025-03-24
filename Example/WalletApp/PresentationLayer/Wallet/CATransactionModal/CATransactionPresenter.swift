import UIKit
import Combine
import ReownWalletKit
import Foundation
import BigInt

final class CATransactionPresenter: ObservableObject {
    enum Errors: LocalizedError {
        case invalidURL
        case invalidResponse
        case invalidData
        case noSolanaAccountFound
    }

    // Published properties to be used in the view
    @Published var payingAmount: String = ""
    @Published var balanceAmount: String = ""
    @Published var appURL: String = ""
    @Published var networkName: String!
    @Published var estimatedFees: String = ""
    @Published var bridgeFee: String = ""
    @Published var executionSpeed: String = "Fast (~20 sec)"
    @Published var transactionCompleted: Bool = false
    @Published var fundingFromNetwork: String!
    @Published var payingTokenSymbol: String = ""
    @Published var payingTokenDecimals: UInt8 = 6 // Default to USDC's 6 decimals

    // Formatted fees with proper decimal places
    @Published var formattedEstimatedFees: String = ""
    @Published var formattedBridgeFee: String = ""
    
    // Dollar value of the transaction
    @Published var payingDollarValue: String = "$0.00"

    private let sessionRequest: Request?
    var fundingFrom: [FundingMetadata] {
        return uiFields.routeResponse.metadata.fundingFrom
    }
    var initialTransactionMetadata: InitialTransactionMetadata {
        return uiFields.routeResponse.metadata.initialTransaction
    }
    let router: CATransactionRouter
    let importAccount: ImportAccount
    var uiFields: UiFields
    let call: Call
    var chainId: Blockchain
    let from: String
    
    // Add balance provider for token balances
    private let balanceProvider = EthBalanceProvider()

    private var disposeBag = Set<AnyCancellable>()

    init(
        sessionRequest: Request?,
        importAccount: ImportAccount,
        router: CATransactionRouter,
        call: Call,
        from: String,
        chainId: Blockchain,
        uiFields: UiFields
    ) {
        self.sessionRequest = sessionRequest
        self.router = router
        self.importAccount = importAccount
        self.chainId = chainId
        self.call = call
        self.from = from
        self.uiFields = uiFields
        self.networkName = network(for: chainId.absoluteString)
        self.fundingFromNetwork = network(for: fundingFrom[0].chainId)
        
        // Get token information from initialTransactionMetadata
        self.payingTokenSymbol = uiFields.routeResponse.metadata.initialTransaction.symbol

        self.payingTokenDecimals = uiFields.routeResponse.metadata.initialTransaction.decimals

        setupInitialState()
    }

    // MARK: - Fee Formatting Methods
    
    /// Formats a fee amount string to display with proper decimal places based on token type
    func formatFeeAmount(_ feeString: String) -> String {
        // Check if the fee string has a currency symbol and extract the number part
        if let numberPart = extractAmountFromFormattedString(feeString),
           let feeValue = Double(numberPart) {
            
            // Format fees consistently with 2 decimal places since they're in USD
            let formattedValue = String(format: "%.2f", feeValue)
            return "$\(formattedValue)"
        }
        
        // Return the original string if parsing fails
        return feeString
    }
    
    /// Extracts the numeric part from a formatted fee string (e.g. "$1.23" -> "1.23")
    private func extractAmountFromFormattedString(_ formattedString: String) -> String? {
        // Find the numeric part (assume it's after a currency symbol)
        // This is a simple extraction - handles strings like "$1.23"
        if let currencyIndex = formattedString.firstIndex(of: "$") {
            let numberPart = formattedString[formattedString.index(after: currencyIndex)...]
            return String(numberPart).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    func dismiss() {
        router.dismiss()
    }

    func approveTransactions() async throws -> ExecuteDetails {
        do {
            print("🚀 Starting transaction approval process...")
            ActivityIndicatorManager.shared.start()

            let initialTxHash = uiFields.initial.transactionHashToSign

            var routeTxnSigs = [RouteSig]()
            let signer = ETHSigner(importAccount: importAccount)

            print("📝 Signing route transactions...")
            for route in uiFields.route {
                switch route {
                case .eip155(let txnDetails):
                    var eip155Sigs = [String]()
                    for txnDetail in txnDetails {
                        print("EVM transaction detected")
                        let hash = txnDetail.transactionHashToSign
                            // sign with sol signer
                        let sig = try! signer.signHash(hash)
                        eip155Sigs.append(sig)
                        print("🔑 Signed transaction hash: \(hash)")
                    }
                    routeTxnSigs.append(.eip155(eip155Sigs))
                case .solana(let solanaTxnDetails):
                    var solanaSigs = [String]()
                    guard let privateKey = SolanaAccountStorage().getPrivateKey() else {
                        throw Errors.noSolanaAccountFound
                    }
                    for txnDetail in solanaTxnDetails {
                        print("Solana transaction detected")

                        let hash = txnDetail.transactionHashToSign

                        let signature = solanaSignPrehash(keypair: privateKey, message: hash)

                        solanaSigs.append(signature)
                        print("🔑 Signed transaction hash: \(hash)")
                    }
                    routeTxnSigs.append(.solana(solanaSigs))
                }
            }

            let initialTxnSig = try! signer.signHash(initialTxHash)
            print("🔑 Signed initial transaction hash: \(initialTxHash)")

            print("📝 Executing transactions through WalletKit...")
            let executeDetails = try await WalletKit.instance.ChainAbstraction.execute(uiFields: uiFields, routeTxnSigs: routeTxnSigs, initialTxnSig: initialTxnSig)

            print("✅ Transaction approval process completed successfully.")
            AlertPresenter.present(message: "Transaction approved successfully", type: .success)
            if let sessionRequest = sessionRequest {
                try await WalletKit.instance.respond(topic: sessionRequest.topic, requestId: sessionRequest.id, response: .response(AnyCodable(executeDetails.initialTxnHash)))
            }
            ActivityIndicatorManager.shared.stop()
            await MainActor.run {
                transactionCompleted = true
            }
            return executeDetails
        } catch {
            print("❌ Transaction approval failed with error: \(error.localizedDescription)")
            ActivityIndicatorManager.shared.stop()
            throw error
        }
    }

    @MainActor
    func rejectTransactions() async throws {
        try await respondError()
    }

    func respondError() async throws {
        guard let sessionRequest = sessionRequest else { return }
        do {
            ActivityIndicatorManager.shared.start()
            try await WalletKit.instance.respond(
                topic: sessionRequest.topic,
                requestId: sessionRequest.id,
                response: .error(.init(code: 0, message: ""))
            )
            ActivityIndicatorManager.shared.stop()
            await MainActor.run {
                router.dismiss()
            }
        } catch {
            ActivityIndicatorManager.shared.stop()
            AlertPresenter.present(message: error.localizedDescription, type: .error)
        }
    }

    func network(for chainId: String) -> String {
        let chainIdToNetwork = [
            "eip155:10": "Optimism",
            "eip155:42161": "Arbitrium",
            "eip155:8453": "Base",
            "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "Solana"
        ]
        return chainIdToNetwork[chainId]!
    }

    // Updated to handle different token types based on metadata
    func formatTokenAmount(_ hexAmount: String, decimals: UInt8) -> String {
        // Convert hex to BigUInt for better handling of large numbers
        let cleanHex = hexAmount.hasPrefix("0x") ? String(hexAmount.dropFirst(2)) : hexAmount
        guard let bigUIntValue = BigUInt(cleanHex, radix: 16) else {
            return "Invalid amount"
        }
        
        // Convert to Decimal for proper decimal formatting
        let decimalValue = Decimal(string: bigUIntValue.description) ?? .zero
        
        // Use the appropriate divisor based on token decimals
        let divisor = pow(10, Int(decimals))
        let tokenValue = decimalValue / divisor
        
        // Format based on token type
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        
        if decimals == 18 && payingTokenSymbol == "ETH" {
            // For ETH, show 5 decimal places
            formatter.maximumFractionDigits = 5
        } else if decimals == 18 {
            // For tokens with 18 decimals (like USDS), show 4 decimal places
            formatter.maximumFractionDigits = 4
        } else {
            // For tokens with fewer decimals (like USDC/USDT), show 2 decimal places
            formatter.maximumFractionDigits = 2
        }
        
        let valueString = formatter.string(from: NSDecimalNumber(decimal: tokenValue)) ?? "0.00"
        return valueString
    }

    func setupInitialState() {
        // Get transaction fees
        estimatedFees = uiFields.localTotal.formattedAlt
        if !uiFields.bridge.isEmpty {
            bridgeFee = uiFields.bridge.first!.localFee.formattedAlt
        }
        
        // Format fees with proper decimal places (maintain 2 decimal places for USD values)
        formattedEstimatedFees = formatFeeAmount(estimatedFees)
        formattedBridgeFee = formatFeeAmount(bridgeFee)

        // Get app URL if available
        if let session = WalletKit.instance.getSessions().first(where: { $0.topic == sessionRequest?.topic }) {
            self.appURL = session.peer.url
        }
        
        // Set network name
        networkName = network(for: chainId.absoluteString)
        
        // Get transaction amount and token information from metadata
        let metadata = uiFields.routeResponse.metadata.initialTransaction
        let hexAmount = metadata.amount
        
        // Format the paying amount with proper decimal places based on token decimals
        payingAmount = formatTokenAmount(hexAmount, decimals: payingTokenDecimals)
        
        // Set the dollar value if available from uiFields (using localTotal as an approximation)
        let formattedAlt = uiFields.localTotal.formattedAlt
        if formattedAlt.hasPrefix("$") {
            payingDollarValue = formattedAlt
        }
        
        // Fetch token balance
        fetchBalance()
    }
    
    private func fetchBalance() {
        Task {
            do {
                if payingTokenSymbol == "ETH" {
                    // Use EthBalanceProvider for ETH balance
                    let (balance, _) = try await balanceProvider.fetchBalance(
                        address: importAccount.account.address,
                        chainId: chainId,
                        tokenSymbol: "ETH"
                    )
                    
                    await MainActor.run {
                        self.balanceAmount = balance
                    }
                } else {
                    // For other tokens, check if we have a token contract address
                    let tokenContract = initialTransactionMetadata.tokenContract
                    if tokenContract.isEmpty || tokenContract == "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE" {
                        // Native token (like ETH)
                        let (balance, _) = try await balanceProvider.fetchBalance(
                            address: importAccount.account.address,
                            chainId: chainId,
                            tokenSymbol: payingTokenSymbol
                        )
                        
                        await MainActor.run {
                            self.balanceAmount = balance
                        }
                    } else {
                        // ERC20 token
                        let hexBalance = try await WalletKit.instance.erc20Balance(
                            chainId: chainId.absoluteString,
                            token: tokenContract,
                            owner: importAccount.account.address
                        )
                        
                        await MainActor.run {
                            // Convert hex balance to human-readable format using the token's decimals
                            self.balanceAmount = formatTokenAmount(hexBalance, decimals: payingTokenDecimals)
                        }
                    }
                }
            } catch {
                print("Error fetching balance: \(error.localizedDescription)")
                await MainActor.run {
                    self.balanceAmount = "0.00"
                }
            }
        }
    }

    func onViewOnExplorer() {
        // Force unwrap the address from the import account
        let address = importAccount.account.address

        // Mapping of network names to Blockscout URLs
        let networkBaseURLMap: [String: String] = [
            "Optimism": "optimism.blockscout.com",
            "Arbitrium": "arbitrum.blockscout.com",
            "Base": "base.blockscout.com"
        ]

        // Force unwrap the base URL for the current network
        let baseURL = networkBaseURLMap[networkName]!

        // Construct the explorer URL
        let explorerURL = URL(string: "https://\(baseURL)/address/\(address)")!

        // Open the URL in Safari
        UIApplication.shared.open(explorerURL, options: [:], completionHandler: nil)
        print("🌐 Opened explorer URL: \(explorerURL)")
    }
}

// MARK: - SceneViewModel
extension CATransactionPresenter: SceneViewModel {}

// MARK: - Extensions for API Models
extension FundingMetadata {
    /// Returns the decimals as UInt8 for use with formatTokenAmount
    var decimalsUInt8: UInt8 {
        // First convert to Int explicitly, then to UInt8 to avoid ambiguity
        return UInt8(Int(decimals))
    }
}




