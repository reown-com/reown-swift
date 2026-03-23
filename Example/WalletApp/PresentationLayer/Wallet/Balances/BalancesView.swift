import SwiftUI

// MARK: - Pre-rendered Copy Icon

private let copyIconImage: UIImage = {
    let size = CGSize(width: 20, height: 20)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let s = size.width / 20
        let path = UIBezierPath()
        // Front rectangle
        path.move(to: CGPoint(x: 14.0625 * s, y: 5 * s))
        path.addLine(to: CGPoint(x: 3.125 * s, y: 5 * s))
        path.addCurve(to: CGPoint(x: 2.1875 * s, y: 5.9375 * s),
                       controlPoint1: CGPoint(x: 2.87636 * s, y: 5 * s),
                       controlPoint2: CGPoint(x: 2.1875 * s, y: 5.68886 * s))
        path.addLine(to: CGPoint(x: 2.1875 * s, y: 16.875 * s))
        path.addCurve(to: CGPoint(x: 3.125 * s, y: 17.8125 * s),
                       controlPoint1: CGPoint(x: 2.1875 * s, y: 17.1236 * s),
                       controlPoint2: CGPoint(x: 2.87636 * s, y: 17.8125 * s))
        path.addLine(to: CGPoint(x: 14.0625 * s, y: 17.8125 * s))
        path.addCurve(to: CGPoint(x: 15 * s, y: 16.875 * s),
                       controlPoint1: CGPoint(x: 14.3111 * s, y: 17.8125 * s),
                       controlPoint2: CGPoint(x: 15 * s, y: 17.1236 * s))
        path.addLine(to: CGPoint(x: 15 * s, y: 5.9375 * s))
        path.addCurve(to: CGPoint(x: 14.0625 * s, y: 5 * s),
                       controlPoint1: CGPoint(x: 15 * s, y: 5.68886 * s),
                       controlPoint2: CGPoint(x: 14.3111 * s, y: 5 * s))
        path.close()
        // Inner cutout (even-odd will punch this out)
        path.move(to: CGPoint(x: 13.125 * s, y: 15.9375 * s))
        path.addLine(to: CGPoint(x: 4.0625 * s, y: 15.9375 * s))
        path.addLine(to: CGPoint(x: 4.0625 * s, y: 6.875 * s))
        path.addLine(to: CGPoint(x: 13.125 * s, y: 6.875 * s))
        path.addLine(to: CGPoint(x: 13.125 * s, y: 15.9375 * s))
        path.close()
        // Back rectangle
        path.move(to: CGPoint(x: 17.8125 * s, y: 3.125 * s))
        path.addLine(to: CGPoint(x: 17.8125 * s, y: 14.0625 * s))
        path.addCurve(to: CGPoint(x: 16.875 * s, y: 15 * s),
                       controlPoint1: CGPoint(x: 17.8125 * s, y: 14.3111 * s),
                       controlPoint2: CGPoint(x: 17.7137 * s, y: 14.5496 * s))
        path.addCurve(to: CGPoint(x: 15.9375 * s, y: 14.0625 * s),
                       controlPoint1: CGPoint(x: 16.6264 * s, y: 15 * s),
                       controlPoint2: CGPoint(x: 15.9375 * s, y: 14.3111 * s))
        path.addLine(to: CGPoint(x: 15.9375 * s, y: 4.0625 * s))
        path.addLine(to: CGPoint(x: 5.9375 * s, y: 4.0625 * s))
        path.addCurve(to: CGPoint(x: 5 * s, y: 3.125 * s),
                       controlPoint1: CGPoint(x: 5.68886 * s, y: 4.0625 * s),
                       controlPoint2: CGPoint(x: 5 * s, y: 3.37364 * s))
        path.addCurve(to: CGPoint(x: 5.9375 * s, y: 2.1875 * s),
                       controlPoint1: CGPoint(x: 5 * s, y: 2.87636 * s),
                       controlPoint2: CGPoint(x: 5.68886 * s, y: 2.1875 * s))
        path.addLine(to: CGPoint(x: 16.875 * s, y: 2.1875 * s))
        path.addCurve(to: CGPoint(x: 17.8125 * s, y: 3.125 * s),
                       controlPoint1: CGPoint(x: 17.1236 * s, y: 2.1875 * s),
                       controlPoint2: CGPoint(x: 17.8125 * s, y: 2.87636 * s))
        path.close()
        path.usesEvenOddFillRule = true
        UIColor(white: 0, alpha: 1).setFill()
        path.fill()
    }.withRenderingMode(.alwaysTemplate)
}()

// MARK: - Cached Token Image

private class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

private struct CachedTokenImage: View {
    let url: String?
    let symbol: String

    @State private var image: UIImage?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(AppColors.foregroundTertiary)
                    .overlay(
                        Text(String(symbol.prefix(1)))
                            .appFont(.sm)
                            .foregroundColor(AppColors.textSecondary)
                    )
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .onAppear {
            guard !loaded else { return }
            loadImage()
        }
    }

    private func loadImage() {
        guard let urlString = url, let url = URL(string: urlString) else {
            loaded = true
            return
        }
        if let cached = ImageCache.shared.image(for: urlString) {
            self.image = cached
            self.loaded = true
            return
        }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    ImageCache.shared.set(uiImage, for: urlString)
                    self.image = uiImage
                    self.loaded = true
                }
            } catch {
                self.loaded = true
            }
        }
    }
}

// MARK: - Card shape (reused)

private let cardShape = RoundedRectangle(cornerRadius: CGFloat(AppRadius._5))

// MARK: - Balances View

struct BalancesView: View {
    @EnvironmentObject var viewModel: BalancesViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HeaderView(
                    onScan: { viewModel.scanHandler.show() },
                    onNfc: { viewModel.onScanNFC() },
                    isNfcAvailable: viewModel.isNFCAvailable
                )

                if viewModel.isLoading && viewModel.tokenBalances.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.tokenBalances.isEmpty {
                    Spacer()
                    VStack(spacing: Spacing._2) {
                        Text("No tokens found")
                            .foregroundColor(AppColors.textPrimary)
                            .appFont(.h6)

                        Text("Pull to refresh")
                            .foregroundColor(AppColors.textSecondary)
                            .appFont(.lg)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing._2) {
                            ForEach(viewModel.tokenBalances) { token in
                                tokenBalanceCard(token)
                            }
                        }
                        .padding(.horizontal, Spacing._5)
                        .padding(.top, Spacing._5)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
        }
        .scanOptionsSheet(
            isPresented: $viewModel.scanHandler.showScanOptions,
            onScanQR: { viewModel.scanHandler.scanQR() },
            onPasteURL: { viewModel.scanHandler.pasteURL() }
        )
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Token Balance Card

    private func tokenBalanceCard(_ token: TokenBalance) -> some View {
        HStack(spacing: Spacing._3) {
            ZStack(alignment: .bottomTrailing) {
                CachedTokenImage(url: token.iconUrl, symbol: token.symbol)
                chainBadge(for: token.chainId)
            }

            VStack(alignment: .leading, spacing: Spacing._05) {
                Text(viewModel.formattedTokenBalance(token))
                    .appFont(.lg)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(viewModel.truncatedAddress)
                    .appFont(.lg)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(uiImage: copyIconImage)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, Spacing._6)
        .padding(.vertical, Spacing._5)
        .background(AppColors.foregroundPrimary, in: cardShape)
        .contentShape(cardShape)
        .onTapGesture {
            viewModel.copyAddress()
        }
    }

    @ViewBuilder
    private func chainBadge(for chainId: String) -> some View {
        if let imageName = ChainIconProvider.imageName(for: chainId) {
            ZStack {
                Circle()
                    .fill(AppColors.backgroundPrimary)
                    .frame(width: 18, height: 18)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
                    .frame(width: 18, height: 18)
            }
            .overlay(
                Circle()
                    .stroke(AppColors.foregroundPrimary, lineWidth: 2)
            )
            .offset(x: 3, y: 3)
        }
    }
}

#if DEBUG
struct BalancesView_Previews: PreviewProvider {
    static var previews: some View {
        BalancesView()
    }
}
#endif
