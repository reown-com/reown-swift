import SwiftUI
import UIKit

// MARK: - WalletToast

struct WalletToast {
    enum MessageType {
        case warning
        case error
        case info
        case success

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .success: return AppColors.iconSuccess
            case .error: return AppColors.iconError
            case .warning: return AppColors.iconWarning
            case .info: return AppColors.iconAccentPrimary
            }
        }
    }

    private static var toastWindow: UIWindow?
    private static var dismissWorkItem: DispatchWorkItem?

    static func present(message: String, type: MessageType) {
        DispatchQueue.main.async {
            dismiss()

            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else { return }

            let toastView = WalletToastView(message: message, type: type)
            let hostingController = UIHostingController(rootView: toastView)
            hostingController.view.backgroundColor = .clear

            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert
            window.backgroundColor = .clear

            window.overrideUserInterfaceStyle = ThemeManager.shared.isDarkMode ? .dark : .light

            window.rootViewController = hostingController
            window.isUserInteractionEnabled = true
            window.isHidden = false

            // Slide in from top
            hostingController.view.transform = CGAffineTransform(translationX: 0, y: -100)
            hostingController.view.alpha = 0

            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                hostingController.view.transform = .identity
                hostingController.view.alpha = 1
            }

            toastWindow = window

            let work = DispatchWorkItem {
                dismissAnimated()
            }
            dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        }
    }

    fileprivate static func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        toastWindow?.isHidden = true
        toastWindow = nil
    }

    private static func dismissAnimated() {
        guard let window = toastWindow else { return }
        UIView.animate(withDuration: 0.3, animations: {
            window.rootViewController?.view.transform = CGAffineTransform(translationX: 0, y: -100)
            window.rootViewController?.view.alpha = 0
        }, completion: { _ in
            dismiss()
        })
    }
}

// MARK: - WalletToastView

private struct WalletToastView: View {
    let message: String
    let type: WalletToast.MessageType

    var body: some View {
        VStack {
            HStack(spacing: Spacing._2) {
                Image(systemName: type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(type.iconColor)
                    .frame(width: 18, height: 18)

                Text(message)
                    .appFont(.lg)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(Spacing._4)
            .frame(maxWidth: .infinity)
            .background(AppColors.foregroundPrimary)
            .cornerRadius(AppRadius._3)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius._3)
                    .stroke(AppColors.borderPrimary, lineWidth: 1)
            )
            .padding(.horizontal, Spacing._5)
            .padding(.top, Spacing._4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onTapGesture {
            WalletToast.dismiss()
        }
    }
}
