import SwiftUI
import ReownWalletKit

struct AppRootView: View {
    @ObservedObject var coordinator: NavigationCoordinator

    var body: some View {
        ZStack {
            MainTabView()
                .environmentObject(coordinator)

            // Modal overlay
            if let modal = coordinator.activeModal {
                modalView(for: modal)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.activeModal?.id)
        .fullScreenCover(isPresented: $coordinator.showScanCamera) {
            makeScanView()
        }
    }

    @ViewBuilder
    private func modalView(for modal: ActiveModal) -> some View {
        switch modal {
        case .sessionProposal(let proposal, let context):
            makeSessionProposalView(proposal: proposal, context: context)

        case .sessionRequest(let request, let context):
            makeSessionRequestView(request: request, context: context)

        case .authRequest(let request, let context):
            makeAuthRequestView(request: request, context: context)

        case .pay(let paymentLink, let accounts):
            makePayView(paymentLink: paymentLink, accounts: accounts)
        }
    }

    private func makeSessionProposalView(proposal: Session.Proposal, context: VerifyContext?) -> some View {
        let presenter = SessionProposalPresenter(
            interactor: SessionProposalInteractor(),
            importAccount: coordinator.importAccount,
            proposal: proposal,
            context: context,
            messageSigner: coordinator.app.messageSigner
        )
        presenter.dismissAction = { [weak coordinator] in coordinator?.dismissModal() }
        return SessionProposalView()
            .environmentObject(presenter)
    }

    private func makeSessionRequestView(request: Request, context: VerifyContext?) -> some View {
        let presenter = SessionRequestPresenter(
            interactor: SessionRequestInteractor(),
            sessionRequest: request,
            importAccount: coordinator.importAccount,
            context: context
        )
        presenter.dismissAction = { [weak coordinator] in coordinator?.dismissModal() }
        return SessionRequestView()
            .environmentObject(presenter)
    }

    private func makeAuthRequestView(request: AuthenticationRequest, context: VerifyContext?) -> some View {
        let presenter = AuthRequestPresenter(
            importAccount: coordinator.importAccount,
            request: request,
            context: context,
            messageSigner: coordinator.app.messageSigner
        )
        presenter.dismissAction = { [weak coordinator] in coordinator?.dismissModal() }
        return AuthRequestView()
            .environmentObject(presenter)
    }

    private func makeScanView() -> some View {
        let presenter = ScanPresenter(
            onValue: { [weak coordinator] value in
                coordinator?.handleScanResult(value)
            },
            onError: { [weak coordinator] _ in
                coordinator?.showScanCamera = false
            }
        )
        presenter.dismissAction = { [weak coordinator] in coordinator?.showScanCamera = false }
        return ScanView()
            .environmentObject(presenter)
    }

    private func makePayView(paymentLink: String, accounts: [String]) -> some View {
        let presenter = PayPresenter(
            paymentLink: paymentLink,
            accounts: accounts,
            importAccount: coordinator.importAccount
        )
        presenter.dismissAction = { [weak coordinator] in coordinator?.dismissModal() }
        return PayContainerView()
            .environmentObject(presenter)
    }
}
