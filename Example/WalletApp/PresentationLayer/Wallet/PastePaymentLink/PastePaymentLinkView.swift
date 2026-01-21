import SwiftUI

struct PastePaymentLinkView: View {
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var presenter: PastePaymentLinkPresenter
    
    @State private var text = ""

    var body: some View {
        ZStack {
            Color(red: 20/255, green: 20/255, blue: 20/255, opacity: 0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                VStack(spacing: 6) {
                    Text("Enter a Payment Link")
                        .foregroundColor(.grey8)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    
                    Text("Paste a WalletConnect Pay URL to start a payment flow.")
                        .foregroundColor(.grey50)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.whiteBackground)
                        
                        HStack {
                            TextField("https://.../?pid=pay_...", text: $text)
                                .padding(.horizontal, 17)
                                .foregroundColor(.grey50)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Button {
                                text = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.systemGrayLight)
                            }
                            .padding(.trailing, 12)
                        }
                    }
                    .frame(height: 44)
                    .padding(.top, 20)
                    .ignoresSafeArea(.keyboard)
                    
                    // Paste from clipboard button
                    Button {
                        if let clipboardString = UIPasteboard.general.string {
                            text = clipboardString
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste from Clipboard")
                        }
                        .foregroundColor(.blue100)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .padding(.top, 10)
                    
                    Button {
                        presenter.onSubmit(text)
                        // Don't dismiss here - the router handles dismissal and presents the Pay flow
                    } label: {
                        Text("Start Payment")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .padding(.vertical, 11)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .blue100,
                                        .blue200
                                    ]),
                                    startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(20)
                    }
                    .padding(.top, 20)
                    .shadow(color: .white.opacity(0.25), radius: 8, y: 2)
                    .disabled(text.isEmpty)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue100)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                    }
                    .padding(.top, 20)
                }
                .padding(20)
                .background(Color.lightBackground)
                .cornerRadius(34)
                .padding(.horizontal, 10)
            }
            .padding(.bottom, 20)
        }
        .edgesIgnoringSafeArea(.top)
    }
}

#if DEBUG
struct PastePaymentLinkView_Previews: PreviewProvider {
    static var previews: some View {
        PastePaymentLinkView()
    }
}
#endif
