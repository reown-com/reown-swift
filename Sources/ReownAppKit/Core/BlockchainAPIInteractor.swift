import Foundation
import WalletConnectNetworking

class BlockchainAPIInteractor: ObservableObject {
    let store: Store
    
    init(store: Store = .shared) {
        self.store = store
    }
    
    func getIdentity() async throws {
        guard 
            let account = store.account,
            store.connectedWith == .wc
        else { return }
        
        let address = account.address
        let chainId = account.chain.absoluteString
        let clientId = try? Relay.instance.getClientId()


        let httpClient = HTTPNetworkClient(host: "rpc.walletconnect.com")
        let response = try await httpClient.request(
            Identity.self,
            at: BlockchainAPI.getIdentity(
                params: .init(
                    address: address,
                    chainId: chainId,
                    projectId: AppKit.config.projectId,
                    clientId: clientId
                )
            )
        )
        
        DispatchQueue.main.async { [self] in
            self.store.identity = response
        }
    }
    
    func getBalance() async throws {
        enum GetBalanceError: Error {
            case noAddress, invalidValue, noChain
        }
        
        guard let address = store.account?.address else {
            throw GetBalanceError.noAddress
        }
        
        let request = RPCRequest(
            method: "eth_getBalance", params: [
                address, "latest"
            ]
        )
        
        guard let chain = store.selectedChain else {
            throw GetBalanceError.noChain
        }
        
        var urlRequest = URLRequest(url: URL(string: chain.rpcUrl)!)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let decodedResponse = try JSONDecoder().decode(RPCResponse.self, from: data)
        let weiFactor = pow(10, chain.token.decimal)
        
        guard let decimalValue = try decodedResponse.result?
            .get(String.self)
            .convertBalanceHexToBigDecimal()?
            .toWei(weiFactor: weiFactor)
        else {
            throw GetBalanceError.invalidValue
        }
        
        let doubleValue = Double(truncating: decimalValue as NSNumber)
        
        DispatchQueue.main.async {
            self.store.balance = doubleValue
        }
    }
}

struct Identity: Codable {
    let name: String?
    let avatar: String?
}

struct BalanceRequest: Encodable {
    init(address: String) {
        self.address = address
    
        self.id = RPCID()
        self.params = [
            address, "latest"
        ]
    }
    
    let address: String
    let id: RPCID
    let jsonrpc: String = "2.0"
    let method: String = "eth_getBalance"
    let params: [String]
}

struct BalanceRpcResponse: Codable {
    let id: RPCID
    let jsonrpc: String
    let result: String?
    let error: RpcError?
    
    struct RpcError: Codable {
        let code: Int
        let message: String
    }
}

extension String {
    func convertBalanceHexToBigDecimal() -> Decimal? {
        let substring = dropFirst(2)
        guard let longValue = UInt64(substring, radix: 16) else { return nil }
        return Decimal(string: "\(longValue)")
    }
}

extension Decimal {
    func toWei(weiFactor: Decimal) -> Decimal {
        return self / weiFactor
    }
}

#if DEBUG
class MockBlockchainAPIInteractor: BlockchainAPIInteractor {
    override func getIdentity() async throws {
        // no-op
    }
    
    override func getBalance() async throws {
        // no-op
    }
}
#endif
