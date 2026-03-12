import UIKit
import WalletConnectNetworking
import ReownWalletKit
import Combine

final class ConfigurationService {

    private var publishers = Set<AnyCancellable>()

    func configure(importAccount: ImportAccount) {
        Networking.configure(
            groupIdentifier: "group.com.walletconnect.sdk",
            projectId: InputConfig.projectId,
            socketFactory: DefaultSocketFactory()
        )
        Networking.instance.setLogging(level: .off)

        let metadata = AppMetadata(
            name: "Swift Wallet",
            description: "wallet description",
            url: "example.wallet",
            icons: ["https://avatars.githubusercontent.com/u/37784886"], 
            redirect: try! AppMetadata.Redirect(native: "walletapp://", universal: "https://lab.web3modal.com/wallet", linkMode: true)
        )

        WalletKit.configure(metadata: metadata, crypto: DefaultCryptoProvider(), pimlicoApiKey: InputConfig.pimlicoApiKey)

        // Initialize SuiSigner
        SuiSigner.initialize(projectId: InputConfig.projectId)

        Sign.instance.setLogging(level: .off)
        Events.instance.setLogging(level: .off)

        if let clientId = try? Networking.interactor.getClientId() {
            LoggingService.instance.setUpUser(account: importAccount.account.absoluteString, clientId: clientId)
            ProfilingService.instance.setUpProfiling(account: importAccount.account.absoluteString, clientId: clientId)
            let groupKeychain = GroupKeychainStorage(serviceIdentifier: "group.com.walletconnect.sdk")
            try! groupKeychain.add(clientId, forKey: "clientId")
        }
        LoggingService.instance.startLogging()

        WalletKit.instance.socketConnectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { status in
            switch status {
            case .connected:
                AlertPresenter.present(message: "Your web socket has connected", type: .success)
            case .disconnected:
                AlertPresenter.present(message: "Your web socket is disconnected", type: .warning)
            }
        }.store(in: &publishers)

        WalletKit.instance.logsPublisher
            .receive(on: DispatchQueue.main)
            .sink { log in
            switch log {
            case .error(let logMessage):
                AlertPresenter.present(message: logMessage.message, type: .error)
            default: return
            }
        }.store(in: &publishers)

        WalletKit.instance.pairingExpirationPublisher
            .receive(on: DispatchQueue.main)
            .sink { pairing in
            AlertPresenter.present(message: "Pairing has expired", type: .warning)
        }.store(in: &publishers)

        WalletKit.instance.sessionProposalExpirationPublisher.sink { _ in
            AlertPresenter.present(message: "Session Proposal has expired", type: .warning)
        }.store(in: &publishers)

        WalletKit.instance.requestExpirationPublisher.sink { _ in
            AlertPresenter.present(message: "Session Request has expired", type: .warning)
        }.store(in: &publishers)

    }
}
