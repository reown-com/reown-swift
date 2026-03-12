import SwiftUI
import ReownWalletKit

struct WalletView: View {
    @EnvironmentObject var presenter: WalletPresenter

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                HeaderView(
                    onPaste: { presenter.onPasteUri() },
                    onScan: { presenter.onScanUri() }
                )

                ZStack {
                    if presenter.sessions.isEmpty {
                        VStack(spacing: Spacing._3) {
                            Image("connect-template")

                            Text("Apps you connect with will appear here. To connect scan or paste the code that's displayed in the app.")
                                .foregroundColor(AppColors.textSecondary)
                                .appFont(.lg)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(Spacing._5)
                    }

                    VStack {
                        ZStack {
                            if !presenter.sessions.isEmpty {
                                List {
                                    ForEach(presenter.sessions, id: \.topic) { session in
                                        connectionView(session: session)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Spacing._4, trailing: 0))
                                            .listRowBackground(Color.clear)
                                    }
                                    .onDelete { indexSet in
                                        Task(priority: .high) {
                                            try await presenter.removeSession(at: indexSet)
                                        }
                                    }
                                }
                                .listStyle(PlainListStyle())
                                .scrollContentBackground(.hidden)
                            }

                            if presenter.showPairingLoading {
                                VStack {
                                    Spacer()

                                    ZStack {
                                        RoundedRectangle(cornerRadius: CGFloat(AppRadius._5)).fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    AppColors.backgroundAccentPrimary,
                                                    AppColors.foregroundAccentPrimary90Solid
                                                ]),
                                                startPoint: .top, endPoint: .bottom)
                                        )
                                        .blink()

                                        Text("WalletConnect is pairing...")
                                            .foregroundColor(AppColors.white)
                                            .appFont(.lg)
                                            .padding(.vertical, Spacing._3)
                                            .padding(.horizontal, Spacing._4)
                                    }
                                    .fixedSize(horizontal: true, vertical: true)
                                }
                            }
                        }

                        Spacer()
                    }
                }
            }
            .padding(.bottom, Spacing._5)
        }
        .alert(presenter.errorMessage, isPresented: $presenter.showError) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $presenter.showConnectedSheet) {
            ZStack {
                VStack {
                    Image("connected")

                    Spacer()
                }

                VStack(spacing: Spacing._2) {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 48, height: 4)
                        .background(AppColors.textPrimary.opacity(0.2))
                        .cornerRadius(100)
                        .padding(.top, Spacing._2)

                    Text("Connected")
                        .foregroundColor(AppColors.textPrimary)
                        .appFont(.h6, weight: .medium)
                        .padding(.top, 168)

                    Text("You can go back to your browser now")
                        .foregroundColor(AppColors.textSecondary)
                        .appFont(.lg, weight: .medium)

                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            presenter.onAppear()
        }
    }

    private func connectionView(session: Session) -> some View {
        Button {
            presenter.onConnection(session: session)
        } label: {
            VStack {
                HStack(spacing: Spacing._3) {
                    AsyncImage(url: URL(string: session.peer.icons.first ?? "")) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .frame(width: 48, height: 48)
                                .background(Color.black)
                                .cornerRadius(CGFloat(AppRadius.full), corners: .allCorners)
                        } else {
                            Color.black
                                .frame(width: 48, height: 48)
                                .cornerRadius(CGFloat(AppRadius.full), corners: .allCorners)
                        }
                    }
                    .padding(.leading, Spacing._4)

                    VStack(alignment: .leading, spacing: Spacing._05) {
                        Text(session.peer.name)
                            .foregroundColor(AppColors.textPrimary)
                            .appFont(.xl, weight: .medium)

                        Text(session.peer.url)
                            .foregroundColor(AppColors.textSecondary)
                            .appFont(.md)
                    }

                    Spacer()

                    Image("forward-shevron")
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.trailing, Spacing._4)
                }
            }
            .padding(.vertical, Spacing._3)
            .background(
                RoundedRectangle(cornerRadius: CGFloat(AppRadius._4))
                    .fill(AppColors.foregroundPrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(AppRadius._4))
                    .stroke(AppColors.borderPrimary, lineWidth: 1)
            )
        }
    }
}

#if DEBUG
struct WalletView_Previews: PreviewProvider {
    static var previews: some View {
        WalletView()
    }
}
#endif
