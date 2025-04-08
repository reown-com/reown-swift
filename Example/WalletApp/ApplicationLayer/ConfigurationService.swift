import UIKit
import WalletConnectNetworking
import WalletConnectNotify
import ReownWalletKit
import Combine

final class ConfigurationService {

    private var publishers = Set<AnyCancellable>()

    func configure(importAccount: ImportAccount) {
        Networking.configure(
            groupIdentifier: "group.com.walletconnect.sdk",
            projectId: InputConfig.projectId,
            socketFactory: DefaultSocketFactory(),
            socketConnectionType: .manual
        )
        Networking.instance.setLogging(level: .debug)

        let metadata = AppMetadata(
            name: "Example Wallet",
            description: "wallet description",
            url: "example.wallet",
            icons: ["https://avatars.githubusercontent.com/u/37784886"], 
            redirect: try! AppMetadata.Redirect(native: "walletapp://", universal: "https://lab.web3modal.com/wallet", linkMode: true)
        )

        WalletKit.configure(metadata: metadata, crypto: DefaultCryptoProvider(), environment: BuildConfiguration.shared.apnsEnvironment, pimlicoApiKey: InputConfig.pimlicoApiKey)


        Notify.configure(
            environment: BuildConfiguration.shared.apnsEnvironment,
            crypto: DefaultCryptoProvider()
        )

        Notify.instance.setLogging(level: .off)
        Sign.instance.setLogging(level: .debug)
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

        Task {
            do {
               // let params = try await Notify.instance.prepareRegistration(account: importAccount.account, domain: "com.walletconnect")
               // let signature = importAccount.onSign(message: params.message)
//                try await Notify.instance.register(params: params, signature: signature)
            } catch {
                DispatchQueue.main.async {
                    let logMessage = LogMessage(message: "Push Server registration failed with: \(error.localizedDescription)")
                    ProfilingService.instance.send(logMessage: logMessage)
                    UIApplication.currentWindow.rootViewController?.showAlert(title: "Register error", error: error)
                }
            }
        }
    }
}
