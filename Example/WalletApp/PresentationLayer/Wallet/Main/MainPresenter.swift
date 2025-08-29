import UIKit
import Combine
import SwiftUI
import WalletConnectUtils
import ReownWalletKit
import YttriumWrapper
import WalletConnectYttrium

struct Tx: Codable {
    let data: String
    let from: String
    let to: String
    let value: String?
}

final class MainPresenter {
    private let interactor: MainInteractor
    private let importAccount: ImportAccount
    private let router: MainRouter
    private let pushRegisterer: PushRegisterer
    private let configurationService: ConfigurationService
    private var disposeBag = Set<AnyCancellable>()

    var tabs: [TabPage] {
        return TabPage.allCases
    }

    var viewControllers: [UIViewController] {
        return [
            router.walletViewController(importAccount: importAccount),
            router.notificationsViewController(importAccount: importAccount),
            router.settingsViewController(importAccount: importAccount)
        ]
    }

    init(router: MainRouter, interactor: MainInteractor, importAccount: ImportAccount, pushRegisterer: PushRegisterer, configurationService: ConfigurationService) {
        defer {
            setupInitialState()
        }
        self.router = router
        self.interactor = interactor
        self.importAccount = importAccount
        self.pushRegisterer = pushRegisterer
        self.configurationService = configurationService
    }
}

// MARK: - Private functions
extension MainPresenter {
    private func setupInitialState() {
        configurationService.configure(importAccount: importAccount)
        pushRegisterer.registerForPushNotifications()
        
        WalletKitRust.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] proposalWithContext in
                router.present(proposal: proposalWithContext.proposal, importAccount: importAccount, context: proposalWithContext.context)
            }
            .store(in: &disposeBag)
        
        interactor.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] (request, context) in
                guard let vc = UIApplication.currentWindow.rootViewController?.topController,
                      vc.restorationIdentifier != SessionRequestModule.restorationIdentifier else {
                    return
                }
                router.dismiss()
                // Chain abstraction routing logic commented out
                /*
                if WalletKitEnabler.shared.isChainAbstractionEnabled && request.method == "eth_sendTransaction" {
                    Task(priority: .background) {
                        try await tryRoutCATransaction(request: request, context: context)
                    }
                } else {
                    router.present(sessionRequest: request, importAccount: importAccount, sessionContext: context)
                }
                */
                // Always use standard session request handling
                router.present(sessionRequest: request, importAccount: importAccount, sessionContext: context)
            }.store(in: &disposeBag)


//        interactor.authenticateRequestPublisher
//            .receive(on: DispatchQueue.main)
//            .sink { [unowned self] result in
//                let requestedChains: Set<Blockchain> = Set(result.request.payload.chains.compactMap { Blockchain($0) })
//                let supportedChains: Set<Blockchain> = [Blockchain("eip155:1")!, Blockchain("eip155:137")!]
//                // Check if there's an intersection between the requestedChains and supportedChains
//                let commonChains = requestedChains.intersection(supportedChains)
//                guard !commonChains.isEmpty else {
//                    AlertPresenter.present(message: "No common chains", type: .error)
//                    return
//                }
//
//                router.present(request: result.request, importAccount: importAccount, context: result.context)
//            }
//            .store(in: &disposeBag)
    }

    // Chain abstraction method commented out
    /*
    private func tryRoutCATransaction(request: Request, context: VerifyContext?) async throws {
        guard request.method == "eth_sendTransaction" else {
            return
        }
        do {
            let tx = try request.params.get([Tx].self)[0]

            let call = Call(
                to: tx.to,
                value: "0",
                input: tx.data
            )

            let solanaAccount = SolanaAccountStorage().getCaip10Account()?.absoluteString
            let eip155Account = importAccount.account.absoluteString

            // Create an array with only non-nil accounts
            var accounts = [eip155Account]
            if let solanaAccount = solanaAccount {
                accounts.append(solanaAccount)
            }

            ActivityIndicatorManager.shared.start()
            let routeResponseSuccess = try await WalletKit.instance.ChainAbstraction.prepare(chainId: request.chainId.absoluteString, from: tx.from, call: call, accounts: accounts, localCurrency: .usd)
            await MainActor.run {
                switch routeResponseSuccess {
                case .success(let routeResponseSuccess):
                    switch routeResponseSuccess {
                    case .available(let uiFields):
                        router.presentCATransaction(sessionRequest: request, importAccount: importAccount, context: context, call: call, from: tx.from, chainId: request.chainId, uiFields: uiFields)
                    case .notRequired(let routeResponseNotRequired):
                        AlertPresenter.present(message: "Routing not required", type: .success)
                        router.present(sessionRequest: request, importAccount: importAccount, sessionContext: context)
                    }
                case .error(let routeResponseError):
                    AlertPresenter.present(message: "Route response error: \(routeResponseError)", type: .success)
                    Task {
                        try await WalletKit.instance.respond(
                            topic: request.topic,
                            requestId: request.id,
                            response: .error(.init(code: 0, message: ""))
                        )
                    }
                }
            }
            ActivityIndicatorManager.shared.stop()
        } catch {
            await MainActor.run {
                AlertPresenter.present(message: error.localizedDescription, type: .error)
            }
            ActivityIndicatorManager.shared.stop()
        }
    }
    */
}
