import SwiftUI

struct SessionRequestView: View {
    @EnvironmentObject var presenter: SessionRequestPresenter

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)

            VStack {
                Spacer()

                ModalContainer {
                    ModalHeaderBar(closeAction: presenter.dismiss)

                    WCModalHeaderView(
                        appName: presenter.session?.peer.name ?? "Unknown",
                        appIconUrl: presenter.session?.peer.icons.first,
                        intention: "Sign a message for",
                        isLinkMode: LinkModeTopicsStorage.shared.containsTopic(presenter.sessionRequest.topic)
                    )

                    VStack(spacing: Spacing._2) {
                        AppInfoCardView(
                            domain: presenter.session?.peer.url ?? "",
                            validationStatus: presenter.validationStatus
                        )

                        MessageCardView(message: presenter.message)

                        NetworkInfoCardView(chainId: presenter.sessionRequest.chainId.absoluteString)
                    }
                    .padding(.top, Spacing._4)

                    ModalFooterView(
                        cancelTitle: "Cancel",
                        actionTitle: "Sign",
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
struct SessionRequestView_Previews: PreviewProvider {
    static var previews: some View {
        SessionRequestView()
    }
}
#endif
