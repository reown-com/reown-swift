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
                    onScan: { presenter.onScanOptions() }
                )

                ZStack {
                    if presenter.sessions.isEmpty {
                        VStack(spacing: Spacing._2) {
                            Text("No connected apps yet")
                                .foregroundColor(AppColors.textPrimary)
                                .appFont(.h6)

                            Text("Scan a WalletConnect QR code to get started.")
                                .foregroundColor(AppColors.textSecondary)
                                .appFont(.lg)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    VStack {
                        ZStack {
                            if !presenter.sessions.isEmpty {
                                List {
                                    ForEach(presenter.sessions, id: \.topic) { session in
                                        connectionView(session: session)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 0, leading: Spacing._5, bottom: Spacing._2, trailing: Spacing._5))
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
                                .padding(.top, Spacing._7)
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
            HStack(spacing: Spacing._4) {
                // App icon — 42x42, rounded 12px
                AsyncImage(url: URL(string: session.peer.icons.first ?? "")) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        AppColors.foregroundTertiary
                    }
                }
                .frame(width: 42, height: 42)
                .cornerRadius(AppRadius._3)

                // Name + domain
                VStack(alignment: .leading, spacing: Spacing._05) {
                    Text(session.peer.name)
                        .appFont(.lg)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(formattedDomain(session.peer.url))
                        .appFont(.lg)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing._2)

                // Chain icons
                ChainIconsView(
                    chainIds: chainIds(from: session),
                    size: 24,
                    overlap: 8,
                    maxVisible: 4
                )
            }
            .padding(Spacing._5)
            .background(AppColors.foregroundPrimary)
            .cornerRadius(Spacing._5)
        }
    }

    private func formattedDomain(_ urlString: String) -> String {
        var d = urlString
        if let url = URL(string: d), let host = url.host {
            d = host
        }
        if d.hasPrefix("www.") {
            d = String(d.dropFirst(4))
        }
        return d
    }

    private func chainIds(from session: Session) -> [String] {
        var ids = [String]()
        var seen = Set<String>()
        for (_, ns) in session.namespaces {
            for account in ns.accounts {
                let chainId = account.blockchain.absoluteString
                if seen.insert(chainId).inserted {
                    ids.append(chainId)
                }
            }
        }
        return ids
    }
}

#if DEBUG
struct WalletView_Previews: PreviewProvider {
    static var previews: some View {
        WalletView()
    }
}
#endif
