import SwiftUI
import ReownWalletKit
import YttriumWrapper

struct SessionProposalRustView: View {
    @EnvironmentObject var presenter: SessionProposalRustPresenter
    
    @State var text = ""
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
            
            VStack {
                Spacer()
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            presenter.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    .padding()
                }
                VStack(spacing: 0) {
                    Image("header")
                        .resizable()
                        .scaledToFit()
                    
                    HStack {
                        // TODO: Replace with actual proposer name from SessionProposalFfi
                        Text("Rust dApp")
                            .foregroundColor(.grey8)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    
                    .padding(.top, 10)
                    
                    Text("would like to connect")
                        .foregroundColor(.grey8)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            // TODO: Add actual namespace and chain information from SessionProposalFfi
                            Text("Rust-based Session Proposal")
                                .foregroundColor(.grey8)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                            
                            Text("This is a session proposal from the Rust client")
                                .foregroundColor(.grey50)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 10)
                    
                    // Placeholder for namespaces - TODO: implement actual namespace parsing
                    ScrollView {
                        Text("Session Details".uppercased())
                            .foregroundColor(.grey50)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.vertical, 12)
                        
                        Text("Details will be populated once SessionProposalFfi structure is known")
                            .foregroundColor(.grey70)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(height: 150)
                    .cornerRadius(20)
                    .padding(.vertical, 12)
                    
                    switch presenter.validationStatus {
                    case .invalid:
                        verifyDescriptionView(imageName: "exclamationmark.triangle.fill", title: "Invalid domain", description: "This domain cannot be verified. Check the request carefully before approving.", color: .red)
                        
                    case .unknown:
                        verifyDescriptionView(imageName: "exclamationmark.circle.fill", title: "Unknown domain", description: "This domain cannot be verified. Check the request carefully before approving.", color: .orange)
                        
                    case .scam:
                        verifyDescriptionView(imageName: "exclamationmark.shield.fill", title: "Security risk", description: "This website is flagged as unsafe by multiple security providers. Leave immediately to protect your assets.", color: .red)
                        
                    default:
                        EmptyView()
                    }
                    
                    if case .scam = presenter.validationStatus {
                        VStack(spacing: 20) {
                            declineButton()
                            allowButton()
                        }
                        .padding(.top, 25)
                    } else {
                        HStack {
                            declineButton()
                            allowButton()
                        }
                        .padding(.top, 25)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(34)
                .padding(.horizontal, 10)
                
                Spacer()
            }
        }
        .alert(presenter.errorMessage, isPresented: $presenter.showError) {
            Button("OK", role: .cancel) {}
        }
        .sheet(
            isPresented: $presenter.showConnectedSheet,
            onDismiss: presenter.onConnectedSheetDismiss
        ) {
            ConnectedSheetView(title: "Connected")
        }
        .edgesIgnoringSafeArea(.all)
    }

    private func verifyDescriptionView(imageName: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: imageName)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Text(description)
                    .foregroundColor(.grey50)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(Color.grey95)
        .cornerRadius(20, corners: .allCorners)
        .padding(.top, 10)
    }

    private func declineButton() -> some View {
        Button {
            Task(priority: .userInitiated) { try await
                presenter.onReject()
            }
        } label: {
            Text("Decline")
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .foregroundNegative,
                            .lightForegroundNegative
                        ]),
                        startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(20)
        }
        .shadow(color: .white.opacity(0.25), radius: 8, y: 2)
    }

    private func allowButton() -> some View {
        Button {
            Task(priority: .userInitiated) { try await
                presenter.onApprove()
            }
        } label: {
            Text(presenter.validationStatus == .scam ? "Proceed anyway" : "Allow")
                .frame(maxWidth: .infinity)
                .foregroundColor(presenter.validationStatus == .scam ? .grey50 : .white)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .padding(.vertical, 11)
                .background(
                    Group {
                        if presenter.validationStatus == .scam {
                            Color.clear
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .foregroundPositive,
                                    .lightForegroundPositive
                                ]),
                                startPoint: .top, endPoint: .bottom
                            )
                        }
                    }
                )
                .cornerRadius(20)
        }
        .shadow(color: .white.opacity(0.25), radius: 8, y: 2)
    }
}

#if DEBUG
struct SessionProposalRustView_Previews: PreviewProvider {
    static var previews: some View {
        SessionProposalRustView()
    }
}
#endif 