import Foundation

public enum W3MJSONRPC: Codable {
    case eth_requestAccounts
    
    case personal_sign(
        address: String,
        message: String
    )
    case eth_signTransaction(
        from: String,
        to: String?,
        value: String,
        data: String,
        nonce: Int?,
        gas: String?,
        gasPrice: String?,
        maxFeePerGas: String?,
        maxPriorityFeePerGas: String?,
        gasLimit: String?,
        chainId: String
    )
    
    case eth_sendTransaction(
        from: String,
        to: String?,
        value: String,
        data: String,
        nonce: Int?,
        gas: String?,
        gasPrice: String?,
        maxFeePerGas: String?,
        maxPriorityFeePerGas: String?,
        gasLimit: String?,
        chainId: String
    )
    
    case wallet_switchEthereumChain(
        chainId: String
    )
    
    case wallet_addEthereumChain(
        chainId: String,
        blockExplorerUrls: [String]?,
        chainName: String?,
        iconUrls: [String]?,
        nativeCurrency: AddChainNativeCurrency?,
        rpcUrls: [String]
    )
    
    case wallet_watchAsset(
        type: String,
        options: WatchAssetOptions
    )
    
    var rawValues: (method: String, params: [String: Any]) {
        let json = try! JSONEncoder().encode(self)
        let dictionary = try! JSONSerialization.jsonObject(with: json) as! [String: [String: Any]]
        
        let method = dictionary.keys.first!
        let params = dictionary[method]!
        return (method, params)
    }
}

public struct AddChainNativeCurrency: Codable {
    let name: String
    let symbol: String
    let decimals: Int
    
    public init(name: String, symbol: String, decimals: Int) {
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
    }
}

public struct WatchAssetOptions: Codable {
    let address: String
    let symbol: String?
    let decimals: Int?
    let image: String?
    
    public init(address: String, symbol: String?, decimals: Int?, image: String?) {
        self.address = address
        self.symbol = symbol
        self.decimals = decimals
        self.image = image
    }
}
