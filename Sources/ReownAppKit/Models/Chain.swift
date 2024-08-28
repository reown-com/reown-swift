import Foundation

public struct Chain: Identifiable, Hashable {
        
    public var id: String {
        "\(chainNamespace):\(chainReference)"
    }

    public var chainName: String
    public var chainNamespace: String
    public var chainReference: String
    public var requiredMethods: [String]
    public var optionalMethods: [String]
    public var events: [String]
    public var token: Token
    public var rpcUrl: String
    public var blockExplorerUrl: String
    public var imageId: String
    
    public struct Token: Hashable {
        public var name: String
        public var symbol: String
        public var decimal: Int
        
        public init(name: String, symbol: String, decimal: Int) {
            self.name = name
            self.symbol = symbol
            self.decimal = decimal
        }
    }
    
    public init(chainName: String, chainNamespace: String, chainReference: String, requiredMethods: [String], optionalMethods: [String], events: [String], token: Chain.Token, rpcUrl: String, blockExplorerUrl: String, imageId: String) {
        self.chainName = chainName
        self.chainNamespace = chainNamespace
        self.chainReference = chainReference
        self.requiredMethods = requiredMethods
        self.optionalMethods = optionalMethods
        self.events = events
        self.token = token
        self.rpcUrl = rpcUrl
        self.blockExplorerUrl = blockExplorerUrl
        self.imageId = imageId
    }
}

enum EthUtils {
    
    static let walletSwitchEthChain = "wallet_switchEthereumChain"
    static let walletAddEthChain = "wallet_addEthereumChain"
    
    static let ethRequiredMethods = [
        "personal_sign",
        "eth_signTypedData",
        "eth_sendTransaction",
    ]
    static let ethOptionalMethods = [walletSwitchEthChain, walletAddEthChain]
    static let ethMethods = ethRequiredMethods + ethOptionalMethods
    
    static let chainChanged = "chainChanged"
    static let accountsChanged = "accountsChanged"

    static let ethEvents = [chainChanged, accountsChanged]
}

enum ChainPresets {
    static let ethToken = Chain.Token(name: "Ether", symbol: "ETH", decimal: 18)

    static var ethChains: [Chain] = [
        Chain(
            chainName: "Ethereum",
            chainNamespace: "eip155",
            chainReference: "1",
            requiredMethods: [],
            optionalMethods: [],
            events: [],
            token: ethToken,
            rpcUrl: "https://cloudflare-eth.com",
            blockExplorerUrl: "https://etherscan.io",
            imageId: "692ed6ba-e569-459a-556a-776476829e00"
        ),
        Chain(
            chainName: "Arbitrum One",
            chainNamespace: "eip155",
            chainReference: "42161",
            requiredMethods: [],
            optionalMethods: [],
            events: [],
            token: ethToken,
            rpcUrl: "https://arb1.arbitrum.io/rpc",
            blockExplorerUrl: "https://arbiscan.io",
            imageId: "600a9a04-c1b9-42ca-6785-9b4b6ff85200"
        ),
        Chain(
            chainName: "Polygon",
            chainNamespace: "eip155",
            chainReference: "137",
            requiredMethods: [],
            optionalMethods: [],
            events: [],
            token: .init(name: "MATIC", symbol: "MATIC", decimal: 18),
            rpcUrl: "https://polygon-rpc.com",
            blockExplorerUrl: "https://polygonscan.com",
            imageId: "41d04d42-da3b-4453-8506-668cc0727900"
        ),
        Chain(
            chainName: "Avalanche",
            chainNamespace: "eip155",
            chainReference: "43114",
            requiredMethods: [],
            optionalMethods: [],
            events: [],
            token: .init(name: "Avalanche", symbol: "AVAX", decimal: 18),
            rpcUrl: "https://api.avax.network/ext/bc/C/rpc",
            blockExplorerUrl: "https://snowtrace.io",
            imageId: "30c46e53-e989-45fb-4549-be3bd4eb3b00"
        ),
        Chain(
            chainName: "BNB Smart Chain",
            chainNamespace: "eip155",
            chainReference: "56",
            requiredMethods: EthUtils.ethRequiredMethods,
            optionalMethods: EthUtils.ethOptionalMethods,
            events: EthUtils.ethEvents,
            token: .init(name: "BNB",symbol: "BNB",decimal:  18),
            rpcUrl: "https://rpc.ankr.com/bsc",
            blockExplorerUrl: "https://bscscan.com",
            imageId: "93564157-2e8e-4ce7-81df-b264dbee9b00"
        ),
        Chain(
            chainName: "OP Mainnet",
            chainNamespace: "eip155",
            chainReference: "10",
            requiredMethods: EthUtils.ethRequiredMethods,
            optionalMethods: EthUtils.ethOptionalMethods,
            events: EthUtils.ethEvents,
            token: ethToken,
            rpcUrl: "https://mainnet.optimism.io",
            blockExplorerUrl: "https://explorer.optimism.io",
            imageId: "ab9c186a-c52f-464b-2906-ca59d760a400"
        ),
        Chain(
            chainName: "Gnosis",
            chainNamespace: "eip155",
            chainReference: "100",
            requiredMethods: EthUtils.ethRequiredMethods,
            optionalMethods: EthUtils.ethOptionalMethods,
            events: EthUtils.ethEvents,
            token: .init(name: "Gnosis",symbol: "xDAI",decimal: 18),
            rpcUrl: "https://rpc.gnosischain.com",
            blockExplorerUrl: "https://blockscout.com/xdai/mainnet",
            imageId: "02b53f6a-e3d4-479e-1cb4-21178987d100"
        ),
        Chain(
            chainName: "zkSync Era",
            chainNamespace: "eip155",
            chainReference: "324",
            requiredMethods: EthUtils.ethRequiredMethods,
            optionalMethods: EthUtils.ethOptionalMethods,
            events: EthUtils.ethEvents,
            token: ethToken,
            rpcUrl: "https://mainnet.era.zksync.io",
            blockExplorerUrl: "https://explorer.zksync.io",
            imageId: "b310f07f-4ef7-49f3-7073-2a0a39685800"
        ),
        Chain(
            chainName: "Zora",
            chainNamespace: "eip155",
            chainReference: "7777777",
            requiredMethods: EthUtils.ethRequiredMethods,
            optionalMethods: EthUtils.ethOptionalMethods,
            events: EthUtils.ethEvents,
            token: ethToken,
            rpcUrl: "https://rpc.zora.energy",
            blockExplorerUrl: "https://explorer.zora.energy",
            imageId: "845c60df-d429-4991-e687-91ae45791600"
        ),
        Chain(
            chainName: "Base",
            chainNamespace: "eip155",
            chainReference: "8453",
            requiredMethods: EthUtils.ethRequiredMethods,
            optionalMethods: EthUtils.ethOptionalMethods,
            events: EthUtils.ethEvents,
            token: ethToken,
            rpcUrl: "https://mainnet.base.org",
            blockExplorerUrl: "https://basescan.org",
            imageId: "7289c336-3981-4081-c5f4-efc26ac64a00"
        ),
        Chain(
            chainName: "Celo",
            chainNamespace: "eip155",
            chainReference: "42220",
            requiredMethods: EthUtils.ethRequiredMethods,
            optionalMethods: EthUtils.ethOptionalMethods,
            events: EthUtils.ethEvents,
            token: .init(name: "CELO",symbol: "CELO",decimal: 18),
            rpcUrl: "https://forno.celo.org",
            blockExplorerUrl: "https://explorer.celo.org/mainnet",
            imageId: "ab781bbc-ccc6-418d-d32d-789b15da1f00"
        ),
        Chain(
            chainName: "Aurora",
            chainNamespace: "eip155",
            chainReference: "1313161554",
            requiredMethods: [],
            optionalMethods: [],
            events: [],
            token: ethToken,
            rpcUrl: "https://mainnet.aurora.dev",
            blockExplorerUrl: "https://aurorascan.dev",
            imageId: "3ff73439-a619-4894-9262-4470c773a100"
        )
    ]
}
