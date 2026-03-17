import SwiftUI

struct ModalFooterView: View {
    let cancelTitle: String
    let actionTitle: String
    var isActionDisabled: Bool = false
    var isCancelLoading: Bool = false
    var isActionLoading: Bool = false
    let onCancel: () -> Void
    let onAction: () -> Void

    private var isAnyLoading: Bool { isCancelLoading || isActionLoading }

    var body: some View {
        HStack(spacing: Spacing._2) {
            Button(action: onCancel) {
                if isCancelLoading {
                    ProgressView()
                        .tint(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing._11)
                } else {
                    Text(cancelTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: Spacing._11)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isAnyLoading)

            Button(action: onAction) {
                if isActionLoading {
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
            .disabled(isActionDisabled || isAnyLoading)
            .opacity(isActionDisabled ? 0.5 : 1.0)
        }
        .padding(.top, Spacing._4)
        .padding(.bottom, Spacing._8)
    }
}
