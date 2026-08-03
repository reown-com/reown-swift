import SwiftUI

/// Full-screen reference flow for the WalletConnect Pay WebView integration.
///
/// Steps:
/// 1. `.input`   — paste/type the `gatewayUrl` returned by the Merchant API.
/// 2. `.webview` — load the checkout; wallet deeplinks are intercepted and forwarded to the OS.
/// 3. `.success` — shown when the checkout posts `PAY_SUCCESS`.
struct PayContainerView: View {
    enum Step: Equatable {
        case input
        case webview(URL)
        case success(String?)
    }

    let onClose: () -> Void

    @State private var step: Step = .input
    @State private var gatewayUrlText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(red: 25/255, green: 26/255, blue: 26/255)
                .ignoresSafeArea()

            switch step {
            case .input:
                inputView
            case .webview(let url):
                webviewView(url: url)
            case .success(let message):
                successView(message: message)
            }

            // Close button (top-right) — always available.
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .accessibilityIdentifier("pay-webview-close")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .alert("Payment failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Input

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WalletConnect Pay")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Paste the gatewayUrl returned by the Merchant API to open the hosted checkout.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))

            TextField("", text: $gatewayUrlText, prompt: Text("https://pay.walletconnect.com/…").foregroundColor(.white.opacity(0.4)))
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .accessibilityIdentifier("pay-webview-url-field")

            HStack(spacing: 10) {
                Button {
                    if let clipboard = UIPasteboard.general.string {
                        gatewayUrlText = clipboard
                    }
                } label: {
                    Text("Paste")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(16)
                }

                Button {
                    openCheckout()
                } label: {
                    Text("Open Checkout")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 95/255, green: 159/255, blue: 248/255))
                        .cornerRadius(16)
                }
                .accessibilityIdentifier("pay-webview-open")
            }
        }
        .padding(24)
        .padding(.top, 40)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func openCheckout() {
        do {
            let url = try PayURLBuilder.buildPayURL(gatewayUrl: gatewayUrlText)
            isLoading = true
            step = .webview(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - WebView

    private func webviewView(url: URL) -> some View {
        ZStack {
            PayWebView(
                url: url,
                isLoading: $isLoading,
                onSuccess: { message in
                    step = .success(message)
                },
                onFailure: { reason in
                    errorMessage = reason ?? "The payment could not be completed."
                    step = .input
                }
            )
            .ignoresSafeArea(edges: .bottom)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.4)
            }
        }
    }

    // MARK: - Success

    private func successView(message: String?) -> some View {
        SuccessView(message: message, onDone: onClose)
    }
}

/// Animated success confirmation using an SF Symbol (no external animation dependency).
private struct SuccessView: View {
    let message: String?
    let onDone: () -> Void

    @State private var animate = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96, weight: .semibold))
                .foregroundColor(Color(red: 52/255, green: 199/255, blue: 89/255))
                .scaleEffect(animate ? 1.0 : 0.4)
                .opacity(animate ? 1.0 : 0.0)
                .accessibilityIdentifier("pay-webview-success-icon")

            Text("Payment successful")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .opacity(animate ? 1.0 : 0.0)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(animate ? 1.0 : 0.0)
            }

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 95/255, green: 159/255, blue: 248/255))
                    .cornerRadius(16)
            }
            .accessibilityIdentifier("pay-webview-done")
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animate = true
            }
        }
    }
}
