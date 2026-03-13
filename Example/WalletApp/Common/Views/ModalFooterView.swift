import SwiftUI

struct ModalFooterView: View {
    let cancelTitle: String
    let actionTitle: String
    var isActionDisabled: Bool = false
    var isLoading: Bool = false
    let onCancel: () -> Void
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: Spacing._2) {
            Button(action: onCancel) {
                Text(cancelTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing._11)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isLoading)

            Button(action: onAction) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing._11)
                } else {
                    Text(actionTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing._11)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isActionDisabled || isLoading)
            .opacity(isActionDisabled ? 0.5 : 1.0)
        }
        .padding(.top, Spacing._4)
        .padding(.bottom, Spacing._8)
    }
}
