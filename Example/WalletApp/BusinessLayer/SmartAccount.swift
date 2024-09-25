import Foundation
import YttriumWrapper
import WalletConnectUtils

extension YttriumWrapper.AccountClient {
    
    func getAccount() async throws -> Account {
        let chain = try Blockchain(namespace: "eip155", reference: chainId)
        let address = try await getAddress()
        return try Account(blockchain: chain, accountAddress: address)
    }
}

class SmartAccount {
    
    static var instance = SmartAccount()
    
    private var client: AccountClient? {
        didSet {
            if let _ = client {
                clientSetContinuation?.resume()
            }
        }
    }
    
    private var clientSetContinuation: CheckedContinuation<Void, Never>?
    
    private var config: Config?

    private init() {
        
    }
    
    public func configure(entryPoint: String, chainId: Int) {
        self.config = Config(
            entryPoint: entryPoint,
            chainId: chainId
        )
    }
    
    public func register(owner: String, privateKey: String) {
        guard let config = self.config else {
            fatalError("Error - you must call SmartAccount.configure(entryPoint:chainId:onSign:) before accessing the shared instance.")
        }
        assert(owner.count == 40)
        
        let localConfig = YttriumWrapper.Config.local()
        
        let pimlicoBundlerUrl = "https://\(InputConfig.pimlicoBundlerUrl!)"
        let rpcUrl = "https://\(InputConfig.rpcUrl!)"
        let pimlicoSepolia = YttriumWrapper.Config(
            endpoints: .init(
                rpc: .init(baseURL: rpcUrl),
                bundler: .init(baseURL: pimlicoBundlerUrl),
                paymaster: .init(baseURL: pimlicoBundlerUrl)
            )
        )
        
        let pickedConfig = if !(InputConfig.pimlicoBundlerUrl?.isEmpty ?? true) && !(InputConfig.rpcUrl?.isEmpty ?? true) {
            pimlicoSepolia
        } else {
            localConfig
        }
        
        let client = AccountClient(
            ownerAddress: owner,
            entryPoint: config.entryPoint,
            chainId: config.chainId,
            config: pickedConfig,
            safe: false
        )
        client.register(privateKey: privateKey)
        
        self.client = client
    }


    public func getClient() async -> AccountClient {
        if let client = client {
            return client
        }

        await withCheckedContinuation { continuation in
            self.clientSetContinuation = continuation
        }
        
        return client!
    }

    struct Config {
        let entryPoint: String
        let chainId: Int
    }
}

class SmartAccountSafe {
    
    static var instance = SmartAccountSafe()
    
    private var client: AccountClient? {
        didSet {
            if let _ = client {
                clientSetContinuation?.resume()
            }
        }
    }
    
    private var clientSetContinuation: CheckedContinuation<Void, Never>?
    
    private var config: Config?

    private init() {
        
    }
    
    public func configure(entryPoint: String, chainId: Int) {
        self.config = Config(
            entryPoint: entryPoint,
            chainId: chainId
        )
    }
    
    public func register(owner: String, privateKey: String) {
        guard let config = self.config else {
            fatalError("Error - you must call SmartAccount.configure(entryPoint:chainId:onSign:) before accessing the shared instance.")
        }
        assert(owner.count == 40)
        
        let localConfig = YttriumWrapper.Config.local()
        
        let pimlicoBundlerUrl = "https://\(InputConfig.pimlicoBundlerUrl!)"
        let rpcUrl = "https://\(InputConfig.rpcUrl!)"
        let pimlicoSepolia = YttriumWrapper.Config(
            endpoints: .init(
                rpc: .init(baseURL: rpcUrl),
                bundler: .init(baseURL: pimlicoBundlerUrl),
                paymaster: .init(baseURL: pimlicoBundlerUrl)
            )
        )
        
        let pickedConfig = if !(InputConfig.pimlicoBundlerUrl?.isEmpty ?? true) && !(InputConfig.rpcUrl?.isEmpty ?? true) {
            pimlicoSepolia
        } else {
            localConfig
        }
        
        let client = AccountClient(
            ownerAddress: owner,
            entryPoint: config.entryPoint,
            chainId: config.chainId,
            config: pickedConfig,
            safe: true
        )
        client.register(privateKey: privateKey)
        
        self.client = client
    }


    public func getClient() async -> AccountClient {
        if let client = client {
            return client
        }

        await withCheckedContinuation { continuation in
            self.clientSetContinuation = continuation
        }
        
        return client!
    }

    struct Config {
        let entryPoint: String
        let chainId: Int
    }
}
