import UIKit
import Combine
import SwiftUI
import WalletConnectUtils
import ReownWalletKit

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

        interactor.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] session in
                router.present(proposal: session.proposal, importAccount: importAccount, context: session.context)
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
                if WalletKitEnabler.shared.isChainAbstractionEnabled && request.method == "eth_sendTransaction" {
                    Task(priority: .background) {
                        try await tryRoutCATransaction(request: request, context: context)
                    }
                } else {
                    router.present(sessionRequest: request, importAccount: importAccount, sessionContext: context)
                }
            }.store(in: &disposeBag)


        interactor.authenticateRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] result in
                let requestedChains: Set<Blockchain> = Set(result.request.payload.chains.compactMap { Blockchain($0) })
                let supportedChains: Set<Blockchain> = [Blockchain("eip155:1")!, Blockchain("eip155:137")!]
                // Check if there's an intersection between the requestedChains and supportedChains
                let commonChains = requestedChains.intersection(supportedChains)
                guard !commonChains.isEmpty else {
                    AlertPresenter.present(message: "No common chains", type: .error)
                    return
                }

                router.present(request: result.request, importAccount: importAccount, context: result.context)
            }
            .store(in: &disposeBag)
    }

    private func tryRoutCATransaction(request: Request, context: VerifyContext?) async throws {
        struct Tx: Codable {
            let data: String
            let from: String
            let to: String
        }

        guard request.method == "eth_sendTransaction" else {
            return
        }
        do {
            let tx = try request.params.get([Tx].self)[0]

            let transaction = EthTransaction(
                from: tx.from,
                to: tx.to,
                value: "0",
                gas: "0",
                gasPrice: "0",
                data: tx.data,
                nonce: "0",
                maxFeePerGas: "0",
                maxPriorityFeePerGas: "0",
                chainId: request.chainId.absoluteString
            )



            let routeResponseSuccess = try await WalletKit.instance.route(transaction: transaction)

            await MainActor.run {
                switch routeResponseSuccess {
                case .available(let routeResponseAvailable):

                    router.presentCATransaction(sessionRequest: request, importAccount: importAccount, routeResponseAvailable: routeResponseAvailable, context: context)

                case .notRequired(let routeResponseNotRequired):
                    AlertPresenter.present(message: "Routing not required", type: .success)
                    router.present(sessionRequest: request, importAccount: importAccount, sessionContext: context)
                }
            }
        } catch {
            await MainActor.run {
                AlertPresenter.present(message: "CA error: \(error.localizedDescription)", type: .error)
                router.present(sessionRequest: request, importAccount: importAccount, sessionContext: context)
            }
        }
    }
}
