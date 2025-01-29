import Foundation
import Combine
@preconcurrency import ReownWalletKit
import BigInt

final class SendStableCoinPresenter: ObservableObject, SceneViewModel {
    // MARK: - Published Properties

    @Published var selectedNetwork: L2 = .Base {
        didSet {
            // Whenever the user changes networks, refetch balances
            fetchAllBalances()
        }
    }
    @Published var recipient: String = "0x2bb169662b61f3D8f8318F800F686389C8a72961"
    @Published var amount: String = "1"

    /// When true, shows the success sheet
    @Published var transactionCompleted: Bool = false
    @Published var transactionResult: String? = nil

    /// String displayed for USDC balance
    @Published var usdcBalance: String = "0.00"
    /// String displayed for USDT balance
    @Published var usdtBalance: String = "0.00"
    /// Combined top-level balance (USDC + USDT)
    @Published var combinedBalance: String = "0.00"

    let router: SendStableCoinRouter
    let importAccount: ImportAccount

    // MARK: - Init

    init(router: SendStableCoinRouter, importAccount: ImportAccount) {
        self.router = router
        self.importAccount = importAccount

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
              let usdtHex  = try await WalletKit.instance.erc20Balance(
                    chainId: chainString,
                    token: selectedNetwork.usdtContractAddress,
                    owner: owner
                )

                // 2) Convert both from hex → Decimal (accounting for 6 decimals in each token)
                let usdcDecimal = parseHexBalance(usdcHex, decimals: 6)
                let usdtDecimal = parseHexBalance(usdtHex, decimals: 6)

                // 3) Combine them
                let combined = usdcDecimal + usdtDecimal

                // 4) Update published properties on MainActor
                await MainActor.run {
                    self.usdcBalance = formatDecimal(usdcDecimal)
                    self.usdtBalance = formatDecimal(usdtDecimal)
                    self.combinedBalance = formatDecimal(combined)
                }
            } catch {
                // On error, set them to 0.00
                AlertPresenter.present(message: error.localizedDescription, type: .error)
                await MainActor.run {
                    self.usdcBalance = "0.00"
                    self.usdtBalance = "0.00"
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
        do {
            let call = try getCall()

            ActivityIndicatorManager.shared.start()

            let routeResponseSuccess = try await WalletKit.instance.prepare(
                chainId: selectedNetwork.chainId.absoluteString,
                from: importAccount.account.address,
                call: call
            )
            await MainActor.run {
                switch routeResponseSuccess {
                case .success(let routeResponse):
                    switch routeResponse {
                    case .available(let routeResponseAvailable):
                        // If the route is available, present a CA transaction flow
                        router.presentCATransaction(
                            call: call,
                            from: importAccount.account.address,
                            chainId: selectedNetwork.chainId,
                            importAccount: importAccount,
                            routeResponseAvailable: routeResponseAvailable
                        )
                    case .notRequired:
                        // Possibly handle a scenario where no special routing is needed
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

    /// Constructs the `Call` object to send USDC (decimal → base units)
    private func getCall() throws -> Call {
        let eoa = try Account(
            blockchain: selectedNetwork.chainId,
            accountAddress: importAccount.account.address
        )
        let toAccount = try Account(
            blockchain: selectedNetwork.chainId,
            accountAddress: recipient
        )

        // 1) Convert the "amount" string to a Decimal
        guard let decimalAmount = Decimal(string: amount) else {
            throw NSError(domain: "SendStableCoinPresenter", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid numeric input: \(amount)"
            ])
        }

        // 2) Multiply by 10^6 because USDC uses 6 decimals
        let baseUnitsDecimal = decimalAmount * Decimal(1_000_000)

        // 3) Convert that to a String for `prepareUSDCTransferCall`
        let baseUnitsString = NSDecimalNumber(decimal: baseUnitsDecimal).stringValue

        // 4) Create the call object (still using USDC for “sending stablecoin”)
        let call = WalletKit.instance.prepareUSDCTransferCall(
            EOA: eoa,
            to: toAccount,
            amount: baseUnitsString
        )
        return call
    }
}
