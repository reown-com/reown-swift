enum AnalyticsEvent: Equatable {
    case MODAL_LOADED
    case MODAL_OPEN(connected: Bool)
    case MODAL_CLOSE(connected: Bool)
    case CLICK_ALL_WALLETS
    case SELECT_WALLET(name: String, platform: Method)
    case CLICK_NETWORKS
//    case OPEN_ACTIVITY_VIEW //
    case SWITCH_NETWORK(network: Chain)
    case CONNECT_SUCCESS(method: Method, name: String)
    case CONNECT_ERROR(message: String)
    case DISCONNECT_SUCCESS
    case DISCONNECT_ERROR
    case CLICK_WALLET_HELP
    case CLICK_NETWORK_HELP
    case CLICK_GET_WALLET

    
    enum Method: String {
        case qrcode = "qrcode"
        case mobile = "mobile"
    }

//    enum Platform: String {
//        case qrcode = "QR"
//        case mobile = "mobile"
//    }
}
