import Combine
import Foundation
import SwiftUI

class Router: ObservableObject {
    @Published private(set) var currentRoute: any SubPage = Router.ConnectingSubpage.connectWallet
    private(set) var previousRoute: (any SubPage)?
    
    private let uiApplicationWrapper: UIApplicationWrapper
    
    init(uiApplicationWrapper: UIApplicationWrapper = .live) {
        self.uiApplicationWrapper = uiApplicationWrapper
    }
    
    func openURL(_ url: URL, completionHandler: ((Bool) -> Void)? = nil) {
        uiApplicationWrapper.openURL(url, completionHandler)
    }
    
    func canOpenURL(_ url: URL) -> Bool {
        uiApplicationWrapper.canOpenURL(url)
    }
    
    func setRoute(_ route: any SubPage) {
        previousRoute = currentRoute
        withAnimation {
            currentRoute = route
        }
    }
    
    func goBack() {
        let prev = previousRoute ?? Router.ConnectingSubpage.connectWallet
        withAnimation {
            currentRoute = prev
        }
        previousRoute = nil
    }

    func resetRoute() {
        withAnimation {
            currentRoute = ConnectingSubpage.connectWallet
        }
    }
    
    enum AccountSubpage: SubPage {
        case transactions
        case profile
    }

    enum ConnectingSubpage: SubPage {
        case connectWallet
        case qr
        case allWallets
        case whatIsAWallet
        case walletDetail(Wallet)
        case getWallet
    }

    enum NetworkSwitchSubpage: SubPage {
        case selectChain
        case networkDetail(Chain)
        case whatIsANetwork
    }
}

protocol SubPage: Equatable {}
