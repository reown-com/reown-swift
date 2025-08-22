import UIKit
import Combine

import ReownWalletKit
import WalletConnectSign

final class SessionProposalRustPresenter: ObservableObject {
    private let interactor: SessionProposalRustInteractor
    private let router: SessionProposalRustRouter

    let importAccount: ImportAccount
    let sessionProposal: Session.Proposal
    let validationStatus: VerifyContext.ValidationStatus?
    
    @Published var showError = false
    @Published var errorMessage = "Error"
    @Published var showConnectedSheet = false
    
    private var disposeBag = Set<AnyCancellable>()

    init(
        interactor: SessionProposalRustInteractor,
        router: SessionProposalRustRouter,
        importAccount: ImportAccount,
        proposal: Session.Proposal,
        context: VerifyContext?
    ) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
        self.sessionProposal = proposal
        self.importAccount = importAccount
        self.validationStatus = context?.validation
    }
    
    @MainActor
    func onApprove() async throws {
        do {
            ActivityIndicatorManager.shared.start()
            let showConnected = try await interactor.approve(proposal: sessionProposal, EOAAccount: importAccount.account)
            showConnected ? showConnectedSheet.toggle() : router.dismiss()
            ActivityIndicatorManager.shared.stop()
        } catch {
            ActivityIndicatorManager.shared.stop()
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }

    @MainActor
    func onReject() async throws {
        do {
            ActivityIndicatorManager.shared.start()
            try await interactor.reject(proposal: sessionProposal)
            ActivityIndicatorManager.shared.stop()
            router.dismiss()
        } catch {
            ActivityIndicatorManager.shared.stop()
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }
    
    func onConnectedSheetDismiss() {
        router.dismiss()
    }

    func dismiss() {
        router.dismiss()
    }
}

// MARK: - Private functions
private extension SessionProposalRustPresenter {
    func setupInitialState() {
        // TODO: Add session proposal expiration and pairing expiration publishers
        // when available in WalletKitRust
    }
}

// MARK: - SceneViewModel
extension SessionProposalRustPresenter: SceneViewModel {

} 