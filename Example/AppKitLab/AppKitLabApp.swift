import Combine
//import Sentry
import SwiftUI
import UIKit
import WalletConnectSign
import ReownAppKit

#if DEBUG
import Atlantis
#endif


class SocketConnectionManager: ObservableObject {
    @Published var socketConnected: Bool = false
}

@main
class AppKitLabApp: App {
    private var disposeBag = Set<AnyCancellable>()
    private var socketConnectionManager = SocketConnectionManager()


    @State var alertMessage: String = ""

    required init() {
        #if DEBUG
        Atlantis.start()
        #endif

        let projectId = InputConfig.projectId

        // We're tracking Crash Reports / Issues from the Demo App to keep improving the SDK
//        SentrySDK.start { options in
//            options.dsn = "https://8b29c857724b94a32ac07ced45452702@o1095249.ingest.sentry.io/4506394479099904"
//            options.debug = false
//            options.enableTracing = true
//        }
//
//        SentrySDK.configureScope { scope in
//            scope.setContext(value: ["projectId": projectId], key: "Project")
//        }

        let metadata = AppMetadata(
            name: "Web3Modal Swift Dapp",
            description: "Web3Modal DApp sample",
            url: "www.web3modal.com",
            icons: ["https://avatars.githubusercontent.com/u/37784886"],
            redirect: try! .init(native: "w3mdapp://", universal: "https://lab.web3modal.com/web3modal_example", linkMode: true)
        )

        Networking.configure(
            groupIdentifier: "group.com.walletconnect.web3modal",
            projectId: projectId,
            socketFactory: DefaultSocketFactory()
        )

        AppKit.configure(
            projectId: projectId,
            metadata: metadata,
            crypto: DefaultCryptoProvider(),
            authRequestParams: nil, // use .stab() for testing SIWE
            customWallets: [
                .init(
                    id: "swift-sample",
                    name: "Swift Sample Wallet",
                    homepage: "https://walletconnect.com/",
                    imageUrl: "https://avatars.githubusercontent.com/u/37784886?s=200&v=4",
                    order: 1,
                    mobileLink: "walletapp://",
                    linkMode: "https://lab.web3modal.com/wallet"
                )
            ]
        ) { error in
//            SentrySDK.capture(error: error)

            print(error)
        }

        setup()

    }

    func setup() {
        AppKit.instance.socketConnectionStatusPublisher.receive(on: DispatchQueue.main).sink { [unowned self] status in
            print("Socket connection status: \(status)")
            self.socketConnectionManager.socketConnected = (status == .connected)

        }.store(in: &disposeBag)
        AppKit.instance.logger.setLogging(level: .debug)
        Sign.instance.setLogging(level: .debug)
        Networking.instance.setLogging(level: .debug)
        Relay.instance.setLogging(level: .debug)

        AppKit.instance.authResponsePublisher.sink { (id: RPCID, result: Result<(Session?, [Cacao]), AuthError>) in
            switch result {
            case .success((_, _)):
                AlertPresenter.present(message: "User authenticated", type: .success)
            case .failure(let error):
                AlertPresenter.present(message: "User authentication error: \(error)", type: .error)

            }
        }.store(in: &disposeBag)

        Web3Modal.instance.SIWEAuthenticationPublisher.sink { result in
            switch result {
            case .success((let message, let signature)):
                AlertPresenter.present(message: "User authenticated", type: .success)
            case .failure(let error):
                AlertPresenter.present(message: "User authentication error: \(error)", type: .error)
            }
        }.store(in: &disposeBag)
    }

    var body: some Scene {
        WindowGroup { [unowned self] in
            ContentView()
                .environmentObject(socketConnectionManager)
                .onOpenURL { url in
                    Web3Modal.instance.handleDeeplink(url)
                }
                .alert(
                    "Response",
                    isPresented: .init(
                        get: { !self.alertMessage.isEmpty },
                        set: { _ in self.alertMessage = "" }
                    )
                ) {
                    Button("Dismiss", role: .cancel) {}
                } message: {
                    Text(alertMessage)
                }
                .onReceive(Web3Modal.instance.sessionResponsePublisher, perform: { response in
                    switch response.result {
                    case let .response(value):
                        self.alertMessage = "Session response: \(value.stringRepresentation)"
                    case let .error(error):
                        self.alertMessage = "Session error: \(error)"
                    }
                })
        }
    }
}

extension AuthRequestParams {
    static func stub(
        domain: String = "lab.web3modal.com",
        chains: [String] = ["eip155:1", "eip155:137"],
        nonce: String = "32891756",
        uri: String = "https://lab.web3modal.com",
        nbf: String? = nil,
        exp: String? = nil,
        statement: String? = "I accept the ServiceOrg Terms of Service: https://lab.web3modal.com",
        requestId: String? = nil,
        resources: [String]? = nil,
        methods: [String]? = ["personal_sign", "eth_sendTransaction"]
    ) -> AuthRequestParams {
        return try! AuthRequestParams(
            domain: domain,
            chains: chains,
            nonce: nonce,
            uri: uri,
            nbf: nbf,
            exp: exp,
            statement: statement,
            requestId: requestId,
            resources: resources,
            methods: methods
        )
    }
}

