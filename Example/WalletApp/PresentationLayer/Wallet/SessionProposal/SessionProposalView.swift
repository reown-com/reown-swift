import SwiftUI
import ReownWalletKit

struct SessionProposalView: View {
    @EnvironmentObject var presenter: SessionProposalPresenter

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)

            VStack {
                Spacer()

                ModalContainer {
                    ModalHeaderBar(closeAction: presenter.dismiss)

                    WCModalHeaderView(
                        appName: presenter.sessionProposal.proposer.name,
                        appIconUrl: presenter.sessionProposal.proposer.icons.first,
                        intention: "Connect your wallet to"
                    )

                    VStack(spacing: Spacing._2) {
                        AppInfoCardView(
                            domain: presenter.sessionProposal.proposer.url,
                            validationStatus: presenter.validationStatus
                        )

                        NetworkSelectorView(
                            chains: presenter.availableChains,
                            selectedChainIds: $presenter.selectedChainIds,
                            requiredChainIds: presenter.requiredChainIds
                        )
                    }
                    .padding(.top, Spacing._4)

                    ModalFooterView(
                        cancelTitle: "Cancel",
                        actionTitle: "Connect",
                        isActionDisabled: presenter.selectedChainIds.isEmpty,
                        isCancelLoading: presenter.isCancelLoading,
                        isActionLoading: presenter.isActionLoading,
                        onCancel: {
                            Task(priority: .userInitiated) { try await presenter.onReject() }
                        },
                        onAction: {
                            Task(priority: .userInitiated) { try await presenter.onApprove() }
                        }
                    )
                }
            }
        }
        .alert(presenter.errorMessage, isPresented: $presenter.showError) {
            Button("OK", role: .cancel) {}
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#if DEBUG
struct SessionProposalView_Previews: PreviewProvider {
    static var previews: some View {
        SessionProposalView()
    }
}
#endif
