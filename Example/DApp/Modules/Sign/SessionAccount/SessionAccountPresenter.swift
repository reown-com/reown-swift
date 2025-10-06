import UIKit
import Combine

import WalletConnectSign

final class SessionAccountPresenter: ObservableObject {
    enum Errors: Error {
        case notImplemented
    }
    
    @Published var showResponse = false
    @Published var showError = false
    @Published var errorMessage = String.empty
    @Published var showRequestSent = false
    @Published var requesting = false
    var lastRequest: Request?


    private let interactor: SessionAccountInteractor
    private let router: SessionAccountRouter
    private let session: Session
    
    var sessionAccount: AccountDetails
    var response: Response?
    
    private var subscriptions = Set<AnyCancellable>()

    init(
        interactor: SessionAccountInteractor,
        router: SessionAccountRouter,
        sessionAccount: AccountDetails,
        session: Session
    ) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
        self.sessionAccount = sessionAccount
        self.session = session
    }
    
    func onAppear() {}
    
    func onMethod(method: String) {
        do {
            let requestParams = try getRequest(for: method)
            
            let ttl: TimeInterval = 300
            let request = try Request(topic: session.topic, method: method, params: requestParams, chainId: Blockchain(sessionAccount.chain)!, ttl: ttl)
            Task {
                do {
                    ActivityIndicatorManager.shared.start()
                    try await Sign.instance.request(params: request)
                    lastRequest = request
                    ActivityIndicatorManager.shared.stop()
                    
                    let requestId = request.id
                    let sessionTopic = session.topic
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.requesting = true
                        self.openWallet(requstId: requestId, topic: sessionTopic)
                    }
                } catch {
                    ActivityIndicatorManager.shared.stop()
                    requesting = false
                    showError.toggle()
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            showError.toggle()
            errorMessage = error.localizedDescription
        }
    }
    
    func copyUri() {
        UIPasteboard.general.string = sessionAccount.address
    }
}

// MARK: - Private functions
extension SessionAccountPresenter {
    private func setupInitialState() {
        Sign.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] response in
                requesting = false
                presentResponse(response: response)
            }
            .store(in: &subscriptions)
    }
    
    private func getRequest(for method: String) throws -> AnyCodable {
        let account = session.namespaces.first!.value.accounts.first!.address
        if method == "eth_sendTransaction" {
            let tx = Stub.tx(from: account)
            return AnyCodable(tx)
        } else if method == "personal_sign" {
            return AnyCodable(["0x4d7920656d61696c206973206a6f686e40646f652e636f6d202d2031363533333933373535313531", account])
        } else if method == "eth_signTypedData" {
            return AnyCodable([account, Stub.eth_signTypedData])
        }
        throw Errors.notImplemented
    }
    
    private func presentResponse(response: Response) {
        self.response = response
        showResponse.toggle()
    }
    
    private func openWallet(requstId: RPCID, topic: String) {
        // Use the documentation format for HTTP-based redirect links:
        // {YOUR_WALLET_URL}/wc?requestId={requestId}&sessionTopic={session.Topic}
        
        let redirectUrl = session.peer.redirect?.native ?? session.peer.redirect?.universal
        
        if let redirectUrl = redirectUrl {
            var plainAppUrl = redirectUrl
            
            if plainAppUrl.hasPrefix("http://") || plainAppUrl.hasPrefix("https://") {
                // HTTP-based URL - use documentation format with parameters
                if plainAppUrl.hasSuffix("/") {
                    plainAppUrl = String(plainAppUrl.dropLast())
                }
                // Only add /wc if it's not already there
                let wcPath = plainAppUrl.hasSuffix("/wc") ? "" : "/wc"
                let urlString = "\(plainAppUrl)\(wcPath)?requestId=\(requstId.string)&sessionTopic=\(topic)"
                
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                    return
                }
            } else {
                // Custom scheme URL - use simple format without extra parameters
                if let url = URL(string: redirectUrl) {
                    UIApplication.shared.open(url)
                    return
                }
            }
        }
        
        // Final fallback if URL construction fails
        showRequestSent.toggle()
    }
}

// MARK: - SceneViewModel
extension SessionAccountPresenter: SceneViewModel {}

// MARK: Errors
extension SessionAccountPresenter.Errors: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notImplemented:   return "Requested method is not implemented"
        }
    }
}

// MARK: - Transaction Stub
private enum Stub {
    struct Transaction: Codable {
        let from, to, data, gasLimit: String
        let gasPrice, value, nonce: String
    }
    
    static let tx = [Transaction(from: "0x9b2055d370f73ec7d8a03e965129118dc8f5bf83",
                                to: "0x521B4C065Bbdbe3E20B3727340730936912DfA46",
                                data: "0x7c616fe60000000000000000000000000000000000000000000000000000000067741500",
                                gasLimit: "0x5208",
                                gasPrice: "0x013e3d2ed4",
                                value: "0x00",
                                nonce: "0x09")]

    static func tx(from: String) -> [Transaction] {
        return [Transaction(from: from,
                            to: "0x521B4C065Bbdbe3E20B3727340730936912DfA46",
                            data: "0x7c616fe60000000000000000000000000000000000000000000000000000000067741500",
                            gasLimit: "0x5208",
                            gasPrice: "0x013e3d2ed4",
                            value: "0x186A0",
                            nonce: "0x09")]
    }
    static let eth_signTypedData = """
{
"types": {
    "EIP712Domain": [
        {
            "name": "name",
            "type": "string"
        },
        {
            "name": "version",
            "type": "string"
        },
        {
            "name": "chainId",
            "type": "uint256"
        },
        {
            "name": "verifyingContract",
            "type": "address"
        }
    ],
    "Person": [
        {
            "name": "name",
            "type": "string"
        },
        {
            "name": "wallet",
            "type": "address"
        }
    ],
    "Mail": [
        {
            "name": "from",
            "type": "Person"
        },
        {
            "name": "to",
            "type": "Person"
        },
        {
            "name": "contents",
            "type": "string"
        }
    ]
},
"primaryType": "Mail",
"domain": {
    "name": "Ether Mail",
    "version": "1",
    "chainId": 1,
    "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
},
"message": {
    "from": {
        "name": "Cow",
        "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
    },
    "to": {
        "name": "Bob",
        "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
    },
    "contents": "Hello, Bob!"
}
}
"""
}
