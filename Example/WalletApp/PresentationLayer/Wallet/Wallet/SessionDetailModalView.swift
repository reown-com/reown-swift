import SwiftUI
import ReownWalletKit

struct SessionDetailModalView: View {
    let session: Session
    let onDisconnect: () -> Void
    let onClose: () -> Void
    let isDisconnecting: Bool

    var body: some View {
        VStack(spacing: Spacing._5) {
            header

            ScrollView {
                VStack(spacing: Spacing._2) {
                    appInfoCard

                    if !allMethods.isEmpty {
                        detailCard(title: "Methods", content: allMethods.joined(separator: ", "))
                    }

                    if !allEvents.isEmpty {
                        detailCard(title: "Events", content: allEvents.joined(separator: ", "))
                    }
                }
                .padding(.bottom, Spacing._5)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Spacing._5)
        .padding(.top, Spacing._5)
        .background(AppColors.backgroundPrimary)
    }

    // MARK: - Helpers

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

    private var allMethods: [String] {
        var methods = Set<String>()
        for (_, ns) in session.namespaces {
            methods.formUnion(ns.methods)
        }
        return Array(methods).sorted()
    }

    private var allEvents: [String] {
        var events = Set<String>()
        for (_, ns) in session.namespaces {
            events.formUnion(ns.events)
        }
        return Array(events).sorted()
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

    private var header: some View {
        HStack {
            Button(action: onDisconnect) {
                HStack(spacing: Spacing._2) {
                    if isDisconnecting {
                        ProgressView()
                            .tint(AppColors.textInvert)
                    } else {
                        DisconnectIcon()
                            .frame(width: 14, height: 14)
                            .foregroundColor(AppColors.textInvert)
                        Text("Disconnect")
                            .appFont(.lg)
                            .foregroundColor(AppColors.textInvert)
                    }
                }
                .padding(.horizontal, Spacing._4)
                .padding(.vertical, Spacing._3)
                .background(AppColors.backgroundInvert)
                .cornerRadius(AppRadius._3)
            }
            .disabled(isDisconnecting)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius._3)
                            .stroke(AppColors.borderSecondary, lineWidth: 1)
                    )
            }
        }
    }

    private var appInfoCard: some View {
        HStack(spacing: Spacing._4) {
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

            Spacer()

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

    private func detailCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing._1) {
            Text(title)
                .appFont(.lg)
                .foregroundColor(AppColors.textPrimary)

            Text(content)
                .appFont(.md)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing._5)
        .background(AppColors.foregroundPrimary)
        .cornerRadius(Spacing._5)
    }
}

// MARK: - Disconnect Icon (14×14 SVG)

private struct DisconnectIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 14
        let sy = rect.height / 14

        var path = Path()

        // Upper-right broken link arc
        path.move(to: CGPoint(x: 10.7078 * sx, y: 3.29222 * sy))
        path.addCurve(
            to: CGPoint(x: 8.54714 * sx, y: 3.2873 * sy),
            control1: CGPoint(x: 10.4215 * sx, y: 3.00587 * sy),
            control2: CGPoint(x: 9.62851 * sx, y: 2.84367 * sy)
        )
        // Intermediate control via two cubics approximating the original path
        path.addLine(to: CGPoint(x: 7.91222 * sx, y: 3.95285 * sy))
        path.addCurve(
            to: CGPoint(x: 7.44973 * sx, y: 4.16831 * sy),
            control1: CGPoint(x: 7.85342 * sx, y: 4.01782 * sy),
            control2: CGPoint(x: 7.7822 * sx, y: 4.07036 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.97268 * sx, y: 3.98735 * sy),
            control1: CGPoint(x: 7.36216 * sx, y: 4.17152 * sy),
            control2: CGPoint(x: 7.27483 * sx, y: 4.15717 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.76943 * sx, y: 3.51936 * sy),
            control1: CGPoint(x: 6.90927 * sx, y: 3.92686 * sy),
            control2: CGPoint(x: 6.85862 * sx, y: 3.85429 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.96285 * sx, y: 3.04722 * sy),
            control1: CGPoint(x: 6.76852 * sx, y: 3.43173 * sy),
            control2: CGPoint(x: 6.78516 * sx, y: 3.34481 * sy)
        )
        path.addLine(to: CGPoint(x: 7.6016 * sx, y: 2.37511 * sy))
        path.addLine(to: CGPoint(x: 7.61253 * sx, y: 2.36418 * sy))
        path.addCurve(
            to: CGPoint(x: 9.62339 * sx, y: 1.53125 * sy),
            control1: CGPoint(x: 8.14585 * sx, y: 1.83086 * sy),
            control2: CGPoint(x: 8.86917 * sx, y: 1.53125 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 11.6343 * sx, y: 2.36418 * sy),
            control1: CGPoint(x: 10.3776 * sx, y: 1.53125 * sy),
            control2: CGPoint(x: 11.1009 * sx, y: 1.83086 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 12.4672 * sx, y: 4.37503 * sy),
            control1: CGPoint(x: 12.1676 * sx, y: 2.89749 * sy),
            control2: CGPoint(x: 12.4672 * sx, y: 3.62082 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 11.6343 * sx, y: 6.38589 * sy),
            control1: CGPoint(x: 12.4672 * sx, y: 5.12925 * sy),
            control2: CGPoint(x: 12.1676 * sx, y: 5.85258 * sy)
        )
        path.addLine(to: CGPoint(x: 11.6233 * sx, y: 6.39683 * sy))
        path.addLine(to: CGPoint(x: 10.9512 * sx, y: 7.03722 * sy))
        path.addCurve(
            to: CGPoint(x: 10.4868 * sx, y: 7.20645 * sy),
            control1: CGPoint(x: 10.8244 * sx, y: 7.15201 * sy),
            control2: CGPoint(x: 10.6577 * sx, y: 7.21273 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.036 * sx, y: 7.00361 * sy),
            control1: CGPoint(x: 10.3158 * sx, y: 7.20018 * sy),
            control2: CGPoint(x: 10.1541 * sx, y: 7.12739 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.85464 * sx, y: 6.54378 * sy),
            control1: CGPoint(x: 9.91793 * sx, y: 6.87983 * sy),
            control2: CGPoint(x: 9.85285 * sx, y: 6.71484 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.0456 * sx, y: 6.08785 * sy),
            control1: CGPoint(x: 9.85643 * sx, y: 6.37273 * sy),
            control2: CGPoint(x: 9.92494 * sx, y: 6.20913 * sy)
        )
        path.addLine(to: CGPoint(x: 10.7111 * sx, y: 5.45293 * sy))
        path.addCurve(
            to: CGPoint(x: 11.1556 * sx, y: 4.3719 * sy),
            control1: CGPoint(x: 10.9964 * sx, y: 5.16552 * sy),
            control2: CGPoint(x: 11.1562 * sx, y: 4.77683 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.7078 * sx, y: 3.29222 * sy),
            control1: CGPoint(x: 11.155 * sx, y: 3.96696 * sy),
            control2: CGPoint(x: 10.994 * sx, y: 3.57876 * sy)
        )
        path.closeSubpath()

        // Lower-left broken link arc
        path.move(to: CGPoint(x: 6.08785 * sx, y: 10.0472 * sy))
        path.addLine(to: CGPoint(x: 5.45293 * sx, y: 10.7128 * sy))
        path.addCurve(
            to: CGPoint(x: 4.37011 * sx, y: 11.1613 * sy),
            control1: CGPoint(x: 5.16575 * sx, y: 10.9999 * sy),
            control2: CGPoint(x: 4.77625 * sx, y: 11.1613 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.2873 * sx, y: 10.7128 * sy),
            control1: CGPoint(x: 3.96398 * sx, y: 11.1613 * sy),
            control2: CGPoint(x: 3.57448 * sx, y: 10.9999 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 2.83878 * sx, y: 9.62996 * sy),
            control1: CGPoint(x: 3.00012 * sx, y: 10.4256 * sy),
            control2: CGPoint(x: 2.83878 * sx, y: 10.0361 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.2873 * sx, y: 8.54714 * sy),
            control1: CGPoint(x: 2.83878 * sx, y: 9.22382 * sy),
            control2: CGPoint(x: 3.00012 * sx, y: 8.83432 * sy)
        )
        path.addLine(to: CGPoint(x: 3.95285 * sx, y: 7.91222 * sy))
        path.addCurve(
            to: CGPoint(x: 4.14379 * sx, y: 7.45628 * sy),
            control1: CGPoint(x: 4.07349 * sx, y: 7.79094 * sy),
            control2: CGPoint(x: 4.142 * sx, y: 7.62734 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.96242 * sx, y: 6.99646 * sy),
            control1: CGPoint(x: 4.14557 * sx, y: 7.28523 * sy),
            control2: CGPoint(x: 4.0805 * sx, y: 7.12024 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.51165 * sx, y: 6.79362 * sy),
            control1: CGPoint(x: 3.84435 * sx, y: 6.87267 * sy),
            control2: CGPoint(x: 3.6826 * sx, y: 6.79989 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.04722 * sx, y: 6.96285 * sy),
            control1: CGPoint(x: 3.3407 * sx, y: 6.78734 * sy),
            control2: CGPoint(x: 3.17406 * sx, y: 6.84806 * sy)
        )
        path.addLine(to: CGPoint(x: 2.37511 * sx, y: 7.6016 * sy))
        path.addLine(to: CGPoint(x: 2.36418 * sx, y: 7.61253 * sy))
        path.addCurve(
            to: CGPoint(x: 1.53125 * sx, y: 9.62339 * sy),
            control1: CGPoint(x: 1.83086 * sx, y: 8.14585 * sy),
            control2: CGPoint(x: 1.53125 * sx, y: 8.86917 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 2.36418 * sx, y: 11.6343 * sy),
            control1: CGPoint(x: 1.53125 * sx, y: 10.3776 * sy),
            control2: CGPoint(x: 1.83086 * sx, y: 11.1009 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.37503 * sx, y: 12.4672 * sy),
            control1: CGPoint(x: 2.89749 * sx, y: 12.1676 * sy),
            control2: CGPoint(x: 3.62082 * sx, y: 12.4672 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.38589 * sx, y: 11.6343 * sy),
            control1: CGPoint(x: 5.12925 * sx, y: 12.4672 * sy),
            control2: CGPoint(x: 5.85258 * sx, y: 12.1676 * sy)
        )
        path.addLine(to: CGPoint(x: 6.39683 * sx, y: 11.6233 * sy))
        path.addLine(to: CGPoint(x: 7.03722 * sx, y: 10.9512 * sy))
        path.addCurve(
            to: CGPoint(x: 7.18169 * sx, y: 10.7347 * sy),
            control1: CGPoint(x: 7.09935 * sx, y: 10.8894 * sy),
            control2: CGPoint(x: 7.14847 * sx, y: 10.8158 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 7.23064 * sx, y: 10.4791 * sy),
            control1: CGPoint(x: 7.21491 * sx, y: 10.6536 * sy),
            control2: CGPoint(x: 7.23155 * sx, y: 10.5667 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 7.02739 * sx, y: 10.0111 * sy),
            control1: CGPoint(x: 7.22972 * sx, y: 10.3914 * sy),
            control2: CGPoint(x: 7.17636 * sx, y: 10.2245 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.55034 * sx, y: 9.83012 * sy),
            control1: CGPoint(x: 6.96398 * sx, y: 9.95059 * sy),
            control2: CGPoint(x: 6.80717 * sx, y: 9.87234 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.08785 * sx, y: 10.0456 * sy),
            control1: CGPoint(x: 6.46277 * sx, y: 9.83334 * sy),
            control2: CGPoint(x: 6.37673 * sx, y: 9.85406 * sy)
        )
        path.addLine(to: CGPoint(x: 6.08785 * sx, y: 10.0472 * sy))
        path.closeSubpath()

        // Right stub line
        path.move(to: CGPoint(x: 11.8125 * sx, y: 8.09378 * sy))
        path.addLine(to: CGPoint(x: 10.5 * sx, y: 8.09378 * sy))
        path.addCurve(
            to: CGPoint(x: 10.036 * sx, y: 8.286 * sy),
            control1: CGPoint(x: 10.326 * sx, y: 8.09378 * sy),
            control2: CGPoint(x: 10.1591 * sx, y: 8.16293 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.84378 * sx, y: 8.75003 * sy),
            control1: CGPoint(x: 9.91292 * sx, y: 8.40907 * sy),
            control2: CGPoint(x: 9.84378 * sx, y: 8.57599 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.036 * sx, y: 9.21407 * sy),
            control1: CGPoint(x: 9.84378 * sx, y: 8.92408 * sy),
            control2: CGPoint(x: 9.91292 * sx, y: 9.091 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.5 * sx, y: 9.40628 * sy),
            control1: CGPoint(x: 10.1591 * sx, y: 9.33714 * sy),
            control2: CGPoint(x: 10.326 * sx, y: 9.40628 * sy)
        )
        path.addLine(to: CGPoint(x: 11.8125 * sx, y: 9.40628 * sy))
        path.addCurve(
            to: CGPoint(x: 12.2766 * sx, y: 9.21407 * sy),
            control1: CGPoint(x: 11.9866 * sx, y: 9.40628 * sy),
            control2: CGPoint(x: 12.1535 * sx, y: 9.33714 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 12.4688 * sx, y: 8.75003 * sy),
            control1: CGPoint(x: 12.3996 * sx, y: 9.091 * sy),
            control2: CGPoint(x: 12.4688 * sx, y: 8.92408 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 12.2766 * sx, y: 8.286 * sy),
            control1: CGPoint(x: 12.4688 * sx, y: 8.57599 * sy),
            control2: CGPoint(x: 12.3996 * sx, y: 8.40907 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 11.8125 * sx, y: 8.09378 * sy),
            control1: CGPoint(x: 12.1535 * sx, y: 8.16293 * sy),
            control2: CGPoint(x: 11.9866 * sx, y: 8.09378 * sy)
        )
        path.closeSubpath()

        // Left stub line
        path.move(to: CGPoint(x: 2.18753 * sx, y: 5.90628 * sy))
        path.addLine(to: CGPoint(x: 3.50003 * sx, y: 5.90628 * sy))
        path.addCurve(
            to: CGPoint(x: 3.96407 * sx, y: 5.71407 * sy),
            control1: CGPoint(x: 3.67408 * sx, y: 5.90628 * sy),
            control2: CGPoint(x: 3.841 * sx, y: 5.83714 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.15628 * sx, y: 5.25003 * sy),
            control1: CGPoint(x: 4.08714 * sx, y: 5.591 * sy),
            control2: CGPoint(x: 4.15628 * sx, y: 5.42408 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.96407 * sx, y: 4.786 * sy),
            control1: CGPoint(x: 4.15628 * sx, y: 5.07599 * sy),
            control2: CGPoint(x: 4.08714 * sx, y: 4.90907 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.50003 * sx, y: 4.59378 * sy),
            control1: CGPoint(x: 3.841 * sx, y: 4.66293 * sy),
            control2: CGPoint(x: 3.67408 * sx, y: 4.59378 * sy)
        )
        path.addLine(to: CGPoint(x: 2.18753 * sx, y: 4.59378 * sy))
        path.addCurve(
            to: CGPoint(x: 1.7235 * sx, y: 4.786 * sy),
            control1: CGPoint(x: 2.01349 * sx, y: 4.59378 * sy),
            control2: CGPoint(x: 1.84657 * sx, y: 4.66293 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 1.53128 * sx, y: 5.25003 * sy),
            control1: CGPoint(x: 1.60042 * sx, y: 4.90907 * sy),
            control2: CGPoint(x: 1.53128 * sx, y: 5.07599 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 1.7235 * sx, y: 5.71407 * sy),
            control1: CGPoint(x: 1.53128 * sx, y: 5.42408 * sy),
            control2: CGPoint(x: 1.60042 * sx, y: 5.591 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 2.18753 * sx, y: 5.90628 * sy),
            control1: CGPoint(x: 1.84657 * sx, y: 5.83714 * sy),
            control2: CGPoint(x: 2.01349 * sx, y: 5.90628 * sy)
        )
        path.closeSubpath()

        // Bottom stub line
        path.move(to: CGPoint(x: 8.75003 * sx, y: 9.84378 * sy))
        path.addCurve(
            to: CGPoint(x: 8.286 * sx, y: 10.036 * sy),
            control1: CGPoint(x: 8.57599 * sx, y: 9.84378 * sy),
            control2: CGPoint(x: 8.40907 * sx, y: 9.91292 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 8.09378 * sx, y: 10.5 * sy),
            control1: CGPoint(x: 8.16293 * sx, y: 10.1591 * sy),
            control2: CGPoint(x: 8.09378 * sx, y: 10.326 * sy)
        )
        path.addLine(to: CGPoint(x: 8.09378 * sx, y: 11.8125 * sy))
        path.addCurve(
            to: CGPoint(x: 8.286 * sx, y: 12.2766 * sy),
            control1: CGPoint(x: 8.09378 * sx, y: 11.9866 * sy),
            control2: CGPoint(x: 8.16293 * sx, y: 12.1535 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 8.75003 * sx, y: 12.4688 * sy),
            control1: CGPoint(x: 8.40907 * sx, y: 12.3996 * sy),
            control2: CGPoint(x: 8.57599 * sx, y: 12.4688 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.21407 * sx, y: 12.2766 * sy),
            control1: CGPoint(x: 8.92408 * sx, y: 12.4688 * sy),
            control2: CGPoint(x: 9.091 * sx, y: 12.3996 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.40628 * sx, y: 11.8125 * sy),
            control1: CGPoint(x: 9.33714 * sx, y: 12.1535 * sy),
            control2: CGPoint(x: 9.40628 * sx, y: 11.9866 * sy)
        )
        path.addLine(to: CGPoint(x: 9.40628 * sx, y: 10.5 * sy))
        path.addCurve(
            to: CGPoint(x: 9.21407 * sx, y: 10.036 * sy),
            control1: CGPoint(x: 9.40628 * sx, y: 10.326 * sy),
            control2: CGPoint(x: 9.33714 * sx, y: 10.1591 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 8.75003 * sx, y: 9.84378 * sy),
            control1: CGPoint(x: 9.091 * sx, y: 9.91292 * sy),
            control2: CGPoint(x: 8.92408 * sx, y: 9.84378 * sy)
        )
        path.closeSubpath()

        // Top stub line
        path.move(to: CGPoint(x: 5.25003 * sx, y: 4.15628 * sy))
        path.addCurve(
            to: CGPoint(x: 5.71407 * sx, y: 3.96407 * sy),
            control1: CGPoint(x: 5.42408 * sx, y: 4.15628 * sy),
            control2: CGPoint(x: 5.591 * sx, y: 4.08714 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.90628 * sx, y: 3.50003 * sy),
            control1: CGPoint(x: 5.83714 * sx, y: 3.841 * sy),
            control2: CGPoint(x: 5.90628 * sx, y: 3.67408 * sy)
        )
        path.addLine(to: CGPoint(x: 5.90628 * sx, y: 2.18753 * sy))
        path.addCurve(
            to: CGPoint(x: 5.71407 * sx, y: 1.7235 * sy),
            control1: CGPoint(x: 5.90628 * sx, y: 2.01349 * sy),
            control2: CGPoint(x: 5.83714 * sx, y: 1.84657 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.25003 * sx, y: 1.53128 * sy),
            control1: CGPoint(x: 5.591 * sx, y: 1.60042 * sy),
            control2: CGPoint(x: 5.42408 * sx, y: 1.53128 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.786 * sx, y: 1.7235 * sy),
            control1: CGPoint(x: 5.07599 * sx, y: 1.53128 * sy),
            control2: CGPoint(x: 4.90907 * sx, y: 1.60042 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.59378 * sx, y: 2.18753 * sy),
            control1: CGPoint(x: 4.66293 * sx, y: 1.84657 * sy),
            control2: CGPoint(x: 4.59378 * sx, y: 2.01349 * sy)
        )
        path.addLine(to: CGPoint(x: 4.59378 * sx, y: 3.50003 * sy))
        path.addCurve(
            to: CGPoint(x: 4.786 * sx, y: 3.96407 * sy),
            control1: CGPoint(x: 4.59378 * sx, y: 3.67408 * sy),
            control2: CGPoint(x: 4.66293 * sx, y: 3.841 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.25003 * sx, y: 4.15628 * sy),
            control1: CGPoint(x: 4.90907 * sx, y: 4.08714 * sy),
            control2: CGPoint(x: 5.07599 * sx, y: 4.15628 * sy)
        )
        path.closeSubpath()

        return path
    }
}
