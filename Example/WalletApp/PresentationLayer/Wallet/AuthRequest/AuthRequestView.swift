import SwiftUI

struct AuthRequestView: View {
    @EnvironmentObject var presenter: AuthRequestPresenter

    private var messagesText: String {
        presenter.messages.map { "\($0.0)\n\($0.1)" }.joined(separator: "\n\n")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)

            VStack {
                Spacer()

                ModalContainer {
                    ModalHeaderBar(closeAction: { presenter.dismiss() })

                    WCModalHeaderView(
                        appName: presenter.request.payload.domain,
                        appIconUrl: nil,
                        intention: "Sign a message for",
                        isLinkMode: LinkModeTopicsStorage.shared.containsTopic(presenter.request.topic)
                    )

                    VStack(spacing: Spacing._2) {
                        AppInfoCardView(
                            domain: presenter.request.payload.domain,
                            validationStatus: presenter.validationStatus
                        )

                        if !presenter.messages.isEmpty {
                            MessageCardView(
                                message: messagesText,
                                title: "Messages to sign (\(presenter.messages.count))",
                                maxHeight: 200
                            )
                        }
                    }
                    .padding(.top, Spacing._4)

                    // Footer with Sign One + Cancel/Connect
                    VStack(spacing: Spacing._2) {
                        ModalFooterView(
                            cancelTitle: "Cancel",
                            actionTitle: "Connect",
                            isCancelLoading: presenter.isCancelLoading,
                            isActionLoading: presenter.isActionLoading,
                            onCancel: {
                                Task(priority: .userInitiated) { await presenter.reject() }
                            },
                            onAction: {
                                Task(priority: .userInitiated) { await presenter.signMulti() }
                            }
                        )

                        Button {
                            Task(priority: .userInitiated) { await presenter.signOne() }
                        } label: {
                            if presenter.isSignOneLoading {
                                ProgressView()
                                    .tint(.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: Spacing._11)
                            } else {
                                Text("Sign One")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: Spacing._11)
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(presenter.isActionLoading || presenter.isCancelLoading || presenter.isSignOneLoading)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#if DEBUG
struct AuthRequestView_Previews: PreviewProvider {
    static var previews: some View {
        AuthRequestView()
    }
}
#endif
