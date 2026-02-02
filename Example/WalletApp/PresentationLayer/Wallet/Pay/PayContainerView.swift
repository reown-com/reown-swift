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
                    case .intro:
                        PayIntroView()
                            .environmentObject(presenter)
                    case .webviewDataCollection:
                        if let urlString = presenter.paymentOptionsResponse?.collectData?.url,
                           let url = URL(string: urlString) {
                            PayDataCollectionWebView(
                                url: url,
                                onComplete: { presenter.onICWebViewComplete() },
                                onError: { error in presenter.onICWebViewError(error) }
                            )
                            .frame(height: 550)
                            .background(Color.whiteBackground)
                            .cornerRadius(34)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                        }
                    case .nameInput:
                        PayNameInputView()
                            .environmentObject(presenter)
                    case .dateOfBirth:
                        PayDateOfBirthView()
                            .environmentObject(presenter)
                    case .confirmation:
                        PayConfirmView()
                            .environmentObject(presenter)
                    case .confirming:
                        PayConfirmingView()
                            .environmentObject(presenter)
                    case .success:
                        PaySuccessView()
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
