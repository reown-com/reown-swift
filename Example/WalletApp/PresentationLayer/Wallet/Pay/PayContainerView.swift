import SwiftUI
import WalletConnectPay

struct PayContainerView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .onTapGesture {
                        // Dismiss keyboard when tapping background
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }

                VStack {
                    Spacer()

                    Group {
                        switch presenter.currentStep {
                        case .loading:
                            PayConfirmingView()
                                .environmentObject(presenter)
                        case .options:
                            PayOptionsView()
                                .environmentObject(presenter)
                        case .whyInfoRequired:
                            PayWhyInfoRequiredView()
                                .environmentObject(presenter)
                        case .webviewDataCollection:
                            if let url = presenter.buildICWebViewURL() {
                                PayDataCollectionWebView(
                                    url: url,
                                    onBack: { presenter.goBack() },
                                    onClose: { presenter.dismiss() },
                                    onComplete: { presenter.onICWebViewComplete() },
                                    onError: { error in presenter.onICWebViewError(error) }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 50)
                                .background(AppColors.backgroundPrimary)
                                .ignoresSafeArea(edges: .bottom)
                            }
                        case .summary:
                            PaySummaryView()
                                .environmentObject(presenter)
                        case .confirming:
                            PayConfirmingView()
                                .environmentObject(presenter)
                        case .result:
                            PayResultView()
                                .environmentObject(presenter)
                        }
                    }
                    .transition(.opacity)
                    .id(presenter.currentStep)
                    .accessibilityElement(children: .contain)
                }
                .animation(.easeInOut(duration: 0.25), value: presenter.currentStep)
            }
        }
        .alert(presenter.errorMessage, isPresented: $presenter.showError) {
            Button("OK", role: .cancel) {}
        }
        .ignoresSafeArea()
    }
}

#if DEBUG
struct PayContainerView_Previews: PreviewProvider {
    static var previews: some View {
        PayContainerView()
    }
}
#endif
