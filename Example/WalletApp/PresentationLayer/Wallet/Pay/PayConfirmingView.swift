import SwiftUI
import Combine

struct PayConfirmingView: View {
    @EnvironmentObject var presenter: PayPresenter
    @State private var animationPhase: Int = 0
    @State private var timerCancellable: AnyCancellable?
    
    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: {
                    presenter.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grey50)
                        .frame(width: 30, height: 30)
                        .background(Color.grey95.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Spacer()
                .frame(height: 40)
            
            // Animated blocks grid
            animatedBlocksView
                .frame(width: 80, height: 80)
            
            Spacer()
                .frame(height: 24)
            
            // Loading text
            Text("Confirming your payment...")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.grey8)
            
            Spacer()
                .frame(minHeight: 60, maxHeight: 100)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .onAppear {
            timerCancellable = Timer.publish(every: 0.4, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        animationPhase = (animationPhase + 1) % 4
                    }
                }
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }
    
    private var animatedBlocksView: some View {
        let colors: [[Color]] = [
            [.grey95, .blue100, .grey95.opacity(0.5), .grey8],
            [.blue100, .grey8, .grey95, .grey95.opacity(0.5)],
            [.grey8, .grey95.opacity(0.5), .blue100, .grey95],
            [.grey95.opacity(0.5), .grey95, .grey8, .blue100]
        ]
        
        let currentColors = colors[animationPhase]
        
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(currentColors[0])
                    .frame(width: 36, height: 36)
                RoundedRectangle(cornerRadius: 6)
                    .fill(currentColors[1])
                    .frame(width: 36, height: 36)
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(currentColors[2])
                    .frame(width: 36, height: 36)
                RoundedRectangle(cornerRadius: 6)
                    .fill(currentColors[3])
                    .frame(width: 36, height: 36)
            }
        }
    }
}

#if DEBUG
struct PayConfirmingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayConfirmingView()
        }
    }
}
#endif
