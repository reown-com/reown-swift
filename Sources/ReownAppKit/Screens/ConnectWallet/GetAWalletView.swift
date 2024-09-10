import SwiftUI


struct GetAWalletView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var store: Store

    var body: some View {
        VStack {
            ForEach(store.featuredWallets.prefix(4), id: \.self) { wallet in
                Button(action: {
                    if let appstoreLink = wallet.appStore {
                        router.openURL(URL(string: appstoreLink)!)
                    }
                }, label: {
                    Text(wallet.name)
                })
                .buttonStyle(W3MListSelectStyle(
                    imageContent: { _ in
                        Group {
                            if let storedImage = store.walletImages[wallet.id] {
                                Image(uiImage: storedImage)
                                    .resizable()
                            } else {
                                Image.Regular.wallet
                                    .resizable()
                                    .padding(Spacing.xxs)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: Radius.xxxs)
                                .fill(.Overgray005)
                        )
                        .backport.overlay {
                            RoundedRectangle(cornerRadius: Radius.xxxs)
                                .stroke(.Overgray010, lineWidth: 1)
                        }
                    }
                ))
            }

            Button(action: {
                router.openURL(URL(string: "https://walletconnect.com/explorer?type=wallet")!)
            }, label: {
                Text("Explore all")
            })
            .buttonStyle(W3MListSelectStyle(
                imageContent: { _ in
                    Image.optionAll
                }
            ))
            .backport.overlay(alignment: .trailing) {
                Image.Bold.externalLink
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(.Foreground200)
                    .padding(.trailing, Spacing.l)
            }
        }
        .padding(Spacing.s)
        .padding(.bottom)
    }
}

#if DEBUG

struct GetAWalletView_Previews: PreviewProvider {
    static let store = {
        let store = Store()
        store.featuredWallets = Wallet.stubList

        for id in Wallet.stubList.map(\.imageId).compactMap({ $0 }).prefix(2) {
            store.walletImages[id] = UIImage(
                named: "MockWalletImage", in: .coreModule, compatibleWith: nil
            )
        }

        return store
    }()

    static var previews: some View {
        GetAWalletView()
            .environmentObject(GetAWalletView_Previews.store)
    }
}

#endif
