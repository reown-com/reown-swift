import SwiftUI

struct PayContainerView: View {
    @EnvironmentObject var presenter: PayPresenter
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                Group {
                    switch presenter.currentStep {
                    case .intro:
                        PayIntroView()
                    case .nameInput:
                        PayNameInputView()
                    case .confirmation:
                        PayConfirmView()
                    }
                }
                .environmentObject(presenter)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: presenter.currentStep)
            }
        }
        .alert(presenter.errorMessage, isPresented: $presenter.showError) {
            Button("OK", role: .cancel) {}
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#if DEBUG
struct PayContainerView_Previews: PreviewProvider {
    static var previews: some View {
        PayContainerView()
    }
}
#endif
