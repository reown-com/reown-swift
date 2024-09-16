import SwiftUI


struct NetworkDetailView: View {
    @EnvironmentObject var store: Store
    
    @ObservedObject var viewModel: NetworkDetailViewModel
    
    
    var body: some View {
        VStack {
            content()
                .onAppear {
                    viewModel.handle(.onAppear)
                }
        }
    }
    
    @ViewBuilder
    func content() -> some View {
        VStack(spacing: 0) {
            chainImage()
                .padding(.top, 20)
                .padding(.bottom, Spacing.l)
        }
        .padding(.horizontal)
        .padding(.bottom, Spacing.xl * 2)
    }
    
    func chainImage() -> some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Image(
                    uiImage: store.chainImages[viewModel.chain.imageId] ?? UIImage()
                )
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(Polygon(count: 6, relativeCornerRadius: 0.25))
                .cornerRadius(Radius.m)
                .backport.overlay(alignment: .bottomTrailing) {
                    Image.Bold.xMark
                        .resizable()
                        .foregroundColor(.Error100)
                        .frame(width: 10, height: 10)
                        .padding(5)
                        .background(Color.Error100.opacity(0.15))
                        .clipShape(Circle())
                        .padding(2)
                        .background(Color.Background125)
                        .clipShape(Circle())
                        .opacity(viewModel.switchFailed ? 1 : 0)
                        .offset(x: 5, y: 5)
                }
                
                if !viewModel.switchFailed {
                    DrawingProgressView(shape: .hexagon, color: .Blue100, lineWidth: 3, isAnimating: .constant(true))
                        .frame(width: 90, height: 90)
                }
            }
            .padding(.bottom, Spacing.s)
            
            Text(!viewModel.switchFailed ? "Approve in wallet" : "Switch declined")
                .font(.paragraph500)
                .foregroundColor(.Foreground100)
            
            Text(!viewModel.switchFailed ? "Accept connection request in your wallet" : "Switch can be declined if chain is not supported by a wallet or previous request is still active")
                .font(.small500)
                .foregroundColor(.Foreground200)
                .multilineTextAlignment(.center)
            
            if viewModel.switchFailed {
                Button {
                    viewModel.handle(.didTapRetry)
                } label: {
                    Text("Try again")
                        .font(.small600)
                        .foregroundColor(.Blue100)
                }
                .padding(Spacing.xl)
                .buttonStyle(W3MButtonStyle(size: .m, variant: .accent, leftIcon: Image.Bold.refresh))
            }
        }
    }
}
