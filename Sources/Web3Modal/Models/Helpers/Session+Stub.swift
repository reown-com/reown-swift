import Foundation

#if DEBUG
extension Session {
    static let stubJson: Data = """
    {
      "peer": {
        "name": "MetaMask Wallet",
        "url": "https://metamask.io/",
        "icons": [],
        "redirect": {
          "native": "metamask://",
          "universal": "https://metamask.app.link/",
          "linkMode: false
        },
        "description": "MetaMask Wallet Integration"
      },
      "namespaces": {
        "eip155": {
          "chains": [
            "eip155:56"
          ],
          "accounts": [
            "eip155:56:0x5c8877144d858e41d8c33f5baa7e67a5e0027e37"
          ],
          "events": [
            "chainChanged",
            "accountsChanged"
          ],
          "methods": [
            "wallet_addEthereumChain",
            "personal_sign",
            "eth_sendTransaction",
            "eth_signTypedData",
            "wallet_switchEthereumChain"
          ]
        }
      },
      "pairingTopic": "08698f505aa6f677823953cbe3d5f34e4f098635f2444096d88977c1850267bb",
      "requiredNamespaces": {},
      "expiryDate": 720702756,
      "topic": "34afbcab97c8b9105f66ea3770cb540d59085c6f0996b4170cb163fee2558f59"
    }
    """.data(using: .utf8)!
    
    static let stub: Session! = {
        try! JSONDecoder().decode(Session.self, from: Session.stubJson)
    }()
}

#endif
