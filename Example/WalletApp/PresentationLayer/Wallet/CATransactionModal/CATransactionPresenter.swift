import UIKit
import Combine
import Web3
import ReownWalletKit

final class CATransactionPresenter: ObservableObject {
    // Published properties to be used in the view
    @Published var payingAmount: Double = 10.00
    @Published var balanceAmount: Double = 5.00
    @Published var bridgingAmount: Double = 5.00
    @Published var bridgingSource: String = "Optimism"
    @Published var appURL: String = "https://sampleapp.com"
    @Published var networkName: String = "Arbitrum"
    @Published var estimatedFees: Double = 4.34
    @Published var bridgeFee: Double = 3.00
    @Published var purchaseFee: Double = 1.34
    @Published var executionSpeed: String = "Fast (~20 sec)"

//    var transactions: [(transaction: Transaction, foundingFrom: FundingFrom)] = []


    private var disposeBag = Set<AnyCancellable>()

    init() {
        defer { setupInitialState() }

    }

    func dismiss() {
        // Implement dismissal logic if needed
    }

    func approveTransactions() {
//        let projectId = Networking.projectId
//
//        for transactionItem in transactions {
//            let transaction = transactionItem.transaction
//            let fundingFrom = transactionItem.foundingFrom
//
//            let rpcUrl = "https://rpc.walletconnect.com/v1?chainId=\(transaction.chainId)&projectId=\(projectId)"
//
//            let web3 = Web3(rpcURL: rpcUrl)
//
//            let contractAddress = try! EthereumAddress(fundingFrom.tokenContract)
//
//            // Fetch nonce
//            firstly {
//                web3.eth.getTransactionCount(address: EthereumAddress(transaction.from)!, block: .latest)
//            }.then { nonce in
//                // Create the contract object
//                let contract = web3.contract(Web3.Utils.erc20ABI, at: contractAddress, abiVersion: 2)!
//
//                // Define method parameters (e.g., transfer to and value)
//                let parameters = [EthereumAddress(transaction.to)!, BigUInt(fundingFrom.amount)!] as [AnyObject]
//
//                // Prepare transaction
//                return try contract.method(
//                    "transfer",
//                    parameters: parameters,
//                    extraData: Data(),
//                    transactionOptions: nil
//                )!.createTransaction(
//                    nonce: nonce,
//                    gasPrice: EthereumQuantity(quantity: BigUInt(21.gwei)),
//                    maxFeePerGas: nil,
//                    maxPriorityFeePerGas: nil,
//                    gasLimit: BigUInt(100000),
//                    from: EthereumAddress(transaction.from)!,
//                    value: EthereumQuantity(quantity: BigUInt(0)),
//                    accessList: [:],
//                    transactionType: .eip1559 // Adjust to match your use case
//                )!.sign(with: EthereumPrivateKey(transaction.from)) // Replace with your actual private key
//            }.then { tx in
//                // Send the raw transaction
//                web3.eth.sendRawTransaction(transaction: tx)
//            }.done { txHash in
//                print("Transaction sent successfully with hash: \(txHash.hex())")
//            }.catch { error in
//                print("Error during transaction approval: \(error.localizedDescription)")
//            }
//        }
    }

    func rejectTransactions() {

    }
}

// MARK: - Private functions
private extension CATransactionPresenter {
    func setupInitialState() {
        // Initialize state if necessary
    }
}

// MARK: - SceneViewModel
extension CATransactionPresenter: SceneViewModel {}


//struct Transaction: Codable {
//    let chainId: String
//    let from: String
//    let to: String
//    let value: String
//    let gas: String
//    let gasPrice: String
//    let data: String
//    let nonce: String
//    let maxFeePerGas: String
//    let maxPriorityFeePerGas: String
//}
//
//struct FundingFrom: Codable {
//    let symbol: String        // e.g., "USDC"
//    let tokenContract: String // Token contract address
//    let chainId: String       // Blockchain ID
//    let amount: String        // Amount to fund
//}
