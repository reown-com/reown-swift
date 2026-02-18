import SwiftUI
import WalletConnectPay

struct PayContainerView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss keyboard when tapping background
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }

                VStack {
                    Spacer()

                    switch presenter.currentStep {
                    case .options:
                        PayOptionsView()
                            .environmentObject(presenter)
                    case .webviewDataCollection:
                        if let url = presenter.buildICWebViewURL() {
                            PayDataCollectionWebView(
                                url: url,
                                onClose: { presenter.goBack() },
                                onComplete: { presenter.onICWebViewComplete() },
                                onError: { error in presenter.onICWebViewError(error) },
                                onFormDataChanged: { fullName, dob, pobAddress in presenter.onICFormDataChanged(fullName: fullName, dob: dob, pobAddress: pobAddress) }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 50)
                            .background(Color.whiteBackground)
                            .ignoresSafeArea(edges: .bottom)
                        }
                    case .nameInput:
                        PayNameInputView()
                            .environmentObject(presenter)
                    case .dateOfBirth:
                        PayDateOfBirthView()
                            .environmentObject(presenter)
                    case .summary:
                        PaySummaryView()
                            .environmentObject(presenter)
                    case .confirming:
                        PayConfirmingView()
                            .environmentObject(presenter)
                    case .success:
                        PaySuccessView()
                            .environmentObject(presenter)
                    case .whyInfoRequired:
                        PayWhyInfoRequiredView()
                            .environmentObject(presenter)
                    }
                }
            }
        }
        .alert(presenter.errorMessage, isPresented: $presenter.showError) {
            Button("OK", role: .cancel) {}
        }
        .ignoresSafeArea(.container, edges: [.top, .horizontal])
    }
}

#if DEBUG
struct PayContainerView_Previews: PreviewProvider {
    static var previews: some View {
        PayContainerView()
    }
}
#endif
