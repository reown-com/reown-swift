//import CoinbaseWalletSDK

extension W3MJSONRPC {
//    func toCbAction() -> Web3JSONRPC? {
//        switch self {
//        case let .personal_sign(address, message):
//            return .personal_sign(
//                address: address,
//                message: message
//            )
//        case .eth_requestAccounts:
//            return .eth_requestAccounts
//        case let .eth_signTransaction(from, to, value, data, nonce, _, gasPrice, maxFeePerGas, maxPriorityFeePerGas, gasLimit, chainId):
//            return .eth_signTransaction(
//                fromAddress: from,
//                toAddress: to,
//                weiValue: value,
//                data: data,
//                nonce: nonce,
//                gasPriceInWei: gasPrice,
//                maxFeePerGas: maxFeePerGas,
//                maxPriorityFeePerGas: maxPriorityFeePerGas,
//                gasLimit: gasLimit,
//                chainId: chainId
//            )
//        case let .eth_sendTransaction(from, to, value, data, nonce, _, gasPrice, maxFeePerGas, maxPriorityFeePerGas, gasLimit, chainId):
//            return .eth_sendTransaction(
//                fromAddress: from,
//                toAddress: to,
//                weiValue: value,
//                data: data,
//                nonce: nonce,
//                gasPriceInWei: gasPrice,
//                maxFeePerGas: maxFeePerGas,
//                maxPriorityFeePerGas: maxPriorityFeePerGas,
//                gasLimit: gasLimit,
//                chainId: chainId
//            )
//        case let .wallet_switchEthereumChain(chainId):
//            return .wallet_switchEthereumChain(chainId: chainId)
//        case let .wallet_addEthereumChain(chainId, blockExplorerUrls, chainName, iconUrls, nativeCurrency, rpcUrls):
//            return .wallet_addEthereumChain(
//                chainId: chainId,
//                blockExplorerUrls: blockExplorerUrls,
//                chainName: chainName,
//                iconUrls: iconUrls,
//                nativeCurrency: nativeCurrency != nil ? .init(
//                    name: nativeCurrency!.name,
//                    symbol: nativeCurrency!.symbol,
//                    decimals: nativeCurrency!.decimals
//                ) : nil,
//                rpcUrls: rpcUrls
//            )
//        case let .wallet_watchAsset(type, options):
//            return .wallet_watchAsset(
//                type: type,
//                options: .init(
//                    address: options.address,
//                    symbol: options.symbol,
//                    decimals: options.decimals,
//                    image: options.image
//                )
//            )
//        }
//    }
}
