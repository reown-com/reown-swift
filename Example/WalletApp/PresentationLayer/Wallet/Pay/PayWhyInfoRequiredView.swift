import SwiftUI

struct PayWhyInfoRequiredView: View {
    @EnvironmentObject var presenter: PayPresenter

    var body: some View {
        VStack(spacing: 0) {
            // Header: back arrow (left) + X close (right)
            HStack {
                Button(action: {
                    presenter.goBack()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grey8)
                }

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

            // Title
            Text("Why we need your information?")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.grey8)
                .multilineTextAlignment(.center)
                .padding(.top, 32)
                .padding(.horizontal, 20)

            // Body
            Text("For regulatory compliance, we collect basic information on your first payment: full name, date of birth, and place of birth.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.grey50)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            // Secondary
            Text("This information is tied to your wallet address and this specific network. If you use the same wallet on this network again, you won't need to provide it again.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.grey50)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            Spacer()
                .frame(minHeight: 30, maxHeight: 50)

            // "Got it!" button
            Button(action: {
                presenter.goBack()
            }) {
                Text("Got it!")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue100, .blue200]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}

#if DEBUG
struct PayWhyInfoRequiredView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayWhyInfoRequiredView()
        }
    }
}
#endif
